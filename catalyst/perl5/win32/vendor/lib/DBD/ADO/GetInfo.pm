#!/usr/local/bin/perl -w
# vim:ts=4:sw=4:tw=78:
#
use strict;

package DBD::ADO::GetInfo;

use DBI			qw(:sql_types);
use vars 		qw(%info %odbc2ado);

my $fmt = '%02d.%02d.%1d%1d%1d%1d';       # ODBC version string: ##.##.#####

my $sql_driver_ver = sprintf $fmt, split(/[\._]/, $DBD::ADO::VERSION);

%info = (
     41 => \&sql_catalog_name_separator   # SQL_CATALOG_NAME_SEPARATOR
,    22 => \&sql_concat_null_behavior     # SQL_CONCAT_NULL_BEHAVIOR
,     6 =>  $INC{'DBD/ADO.pm'}            # SQL_DRIVER_NAME               # XXX
,     7 =>  $sql_driver_ver               # SQL_DRIVER_VER                # XXX
,    28 => \&sql_identifier_case          # SQL_IDENTIFIER_CASE
,    29 => \&sql_identifier_quote_char    # SQL_IDENTIFIER_QUOTE_CHAR
,    89 => \&sql_keywords                 # SQL_KEYWORDS
);

%odbc2ado = (
    114 => 'Catalog Location'             # SQL_CATALOG_LOCATION
,    42 => 'Catalog Term'                 # SQL_CATALOG_TERM
,     2 => 'Data Source Name'             # SQL_DATA_SOURCE_NAME
,    17 => 'DBMS Name'                    # SQL_DBMS_NAME
,    18 => 'DBMS Version'                 # SQL_DBMS_VERSION
#     6 => 'Provider Name'                # SQL_DRIVER_NAME               # XXX
#     7 => 'Provider Version'             # SQL_DRIVER_VER                # XXX
,    40 => 'Procedure Term'               # SQL_PROCEDURE_TERM
,    39 => 'Schema Term'                  # SQL_SCHEMA_TERM
,    45 => 'Table Term'                   # SQL_TABLE_TERM
,    47 => 'User Name'                    # SQL_USER_NAME
);

sub sql_catalog_name_separator {
	my $dbh = shift;
	DBD::ADO::db::ado_schema_dbinfo_literal($dbh,'CATALOG_SEPARATOR') ||'.';
}
sub sql_concat_null_behavior {
	{ 1 => 0 # SQL_CB_NULL
	, 2 => 1 # SQL_CB_NON_NULL
	}->{$_[0]->{ado_conn}->Properties->{'NULL Concatenation Behavior'}{Value}};
}
sub sql_identifier_case {
	{ 1 => 1 # SQL_IC_UPPER
	, 2 => 2 # SQL_IC_LOWER
	, 4 => 3 # SQL_IC_SENSITIVE
	, 8 => 4 # SQL_IC_MIXED
	}->{$_[0]->{ado_conn}->Properties->{'Identifier Case Sensitivity'}{Value}};
}
sub sql_identifier_quote_char {
	my $dbh = shift;
	DBD::ADO::db::ado_schema_dbinfo_literal($dbh,'QUOTE') ||
	DBD::ADO::db::ado_schema_dbinfo_literal($dbh,'QUOTE_PREFIX') ||'"';
}
sub sql_keywords {
	my $dbh = shift;
	my $sth = $dbh->func('adSchemaDBInfoKeywords','OpenSchema');
	my @Keywords = ();
	while ( my $row = $sth->fetch ) {
		push @Keywords, $row->[0];
	}
	return join ',', @Keywords;
}



1;

__END__

#
# $Log: GetInfo.pm,v $
# Revision 1.1  2002/04/14 04:19:18  talowery
# Added additional tests and new module.
#
#
