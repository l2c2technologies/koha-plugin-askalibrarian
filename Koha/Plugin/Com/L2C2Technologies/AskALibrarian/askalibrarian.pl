#!/usr/bin/perl

# Copyright 2018 L2C2 Technologies.
#
# This file is part of Koha::Plugin::Com::L2C2Technologies::AskALibrarian
#
# AskALibrarian Koha Plugin (.kpz) is free software; you can redistribute
# it and/or modify it under the terms of the GNU General Public License 
# as published by the Free Software Foundation; either version 3 of the 
# License, or (at your option) any later version.
#
# AskALibrarian Koha Plugin (.kpz) is distributed in the hope that it will
# be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with AskALibrarian Koha Plugin (.kpz); if not, see 
# <http://www.gnu.org/licenses>.

use Modern::Perl;

use C4::Context;
use lib C4::Context->config("pluginsdir");

use Koha::Plugin::Com::L2C2Technologies::AskALibrarian;

use CGI;

my $cgi = new CGI;

my $askalibrarian = Koha::Plugin::Com::L2C2Technologies::AskALibrarian->new({ cgi => $cgi });

$askalibrarian->tool();
