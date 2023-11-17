#!/usr/bin/perl
# Create: c_V  (Cir Vago)
# Date: 17 Nov 2023
# Web usage:
#            https://www.easysoft.com/developer/languages/perl/sql_server_unix_tutorial.html
#            git: openssl

use strict;
use warnings;

use DBI;
my $user = 'naemon';
my $password = 'MSSSQL-P4Ss';
#Test Particular DB
#my $dbh = DBI->connect("dbi:ODBC:Driver={/opt/microsoft/msodbcsql17/lib64/libmsodbcsql-17.10.so};Server=SQLServerDev;Database=MSSQLSERVER;UID=$user;PWD=$password");
#Test conección
my $dbh = DBI->connect("dbi:ODBC:Driver={/opt/microsoft/msodbcsql17/lib64/libmsodbcsql-17.10.so};Server=SQLServerDev;UID=$user;PWD=$password");

# This query generates a result set with one record in it.
my $sql = "SELECT 1 AS test_col";

# Prepare the statement.
my $sth = $dbh->prepare($sql)
    or die "Can't prepare statement: $DBI::errstr";

# Execute the statement.
$sth->execute();

# Print the column name.
print "$sth->{NAME}->[0]\n";

# Fetch and display the result set value.
while ( my @row = $sth->fetchrow_array ) {
   print "@row\n";
}

# Disconnect the database from the database handle.
$dbh->disconnect;
