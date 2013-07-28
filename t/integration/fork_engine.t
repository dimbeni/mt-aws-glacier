#!/usr/bin/perl

# mt-aws-glacier - Amazon Glacier sync client
# Copyright (C) 2012-2013  Victor Efimov
# http://mt-aws.com (also http://vs-dev.com) vs@vs-dev.com
# License: GPLv3
#
# This file is part of "mt-aws-glacier"
#
#    mt-aws-glacier is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    mt-aws-glacier is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use Test::More tests => 2;
use FindBin;
use lib "$FindBin::RealBin/../", "$FindBin::RealBin/../../lib";
use TestUtils;
use App::MtAws::ForkEngine;
use Carp;
use Config;
use Time::HiRes qw/usleep/;

warning_fatal();

my $rootdir = get_temp_dir();

my @TRUE_CMD = ($Config{'perlpath'}, '-e', '0');

sub fork_engine_test(&&&&)
{
	my ($parent_init, $parent_each, $parent_done, $child_cb) = @_;

	no warnings 'redefine';
	local *App::MtAws::ForkEngine::run_children = sub {
		my ($self, $out, $in) = @_;
		$child_cb->($in, $out);
	};
	local *App::MtAws::ForkEngine::run_parent = sub {
		my ($self, $disp_select) = @_;
		$parent_init->();
		my @ready;
		do { @ready = $disp_select->can_read(); } until @ready || !$!{EINTR};
		for my $fh (@ready) {
			$parent_each->($fh);
		}
		$self->terminate_children();
		$parent_done->();
	};
	my $FE = App::MtAws::ForkEngine->new(options => { concurrency => 1});
	$FE->start_children();
}

fork_engine_test
	sub {
		system @TRUE_CMD;
		usleep(300_000);
	},
	sub {
		my ($fh) = @_;
		is <$fh>, "ready\n";
	},
	sub {
		ok 1, "should not die if parent code executed system command";
	},
	sub {
		my ($in, $out) = @_;
		print $out "ready\n";
		<$in>;
	};




1;