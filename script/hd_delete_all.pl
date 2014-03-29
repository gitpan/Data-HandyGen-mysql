#!perl

use strict;
use warnings;

use DBI;
use YAML qw(LoadFile);
use Data::HandyGen::mysql::TableDef;
use Getopt::Long;
use SQL::Maker;

main();
exit(0);


sub main {
    my $infile;
    my $noutf8 = 0;
    my $verbose = 0;
    my ($dbname, $host, $port, $user, $password);
    GetOptions(
        'i|in|infile=s' => \$infile,
        'd|dbname=s'    => \$dbname,
        'h|host=s'      => \$host,
        'port=i'        => \$port,
        'u|user=s'      => \$user,
        'p|password=s'  => \$password,
        'noutf8'        => \$noutf8,
        'v|verbose'     => \$verbose,
    );
    
    $infile and $dbname or usage();
    
    my $dsn = "dbi:mysql:dbname=$dbname";
    $host and $dsn .= ";host=$host";
    $port and $dsn .= ";port=$port";

    my $dbh = DBI->connect($dsn, $user, $password, { RaiseError => 1, AutoCommit => 0 })
        or die $DBI::errstr;
    $dbh->do("SET NAMES UTF8") unless $noutf8;

    my $inserted = LoadFile($infile);


    if ( ref $inserted eq 'HASH' ) {
        eval {

            my $builder = SQL::Maker->new( driver => 'mysql' );

            $dbh->do(q{SET FOREIGN_KEY_CHECKS = 0});
            for my $table ( keys %$inserted ) {
                my $ids = $inserted->{$table};
                my $table_def = Data::HandyGen::mysql::TableDef->new( dbh => $dbh, table_name => $table );
                my $pk_column = $table_def->pk_columns()->[0];
                
                for my $id (@$ids) {
                    my ($sql, @binds) = $builder->delete($table, { $pk_column => $id });
                    my $sth = $dbh->prepare($sql);
                    my $numrow = $sth->execute(@binds);
                    if ( $numrow >= 1 ) {
                        print "Deleted $table ($id)\n" if $verbose;
                    }
                    else {
                        print "No row affected. $table ($id)\n" if $verbose;
                    }
                }
            }
            $dbh->do(q{SET FOREIGN_KEY_CHECKS = 1});

        };
        if ($@) {
            $dbh->rollback();
        }
        else {
            $dbh->commit();
        }

    }
    else {
        die "Invalid format : $infile\n";
    }

    $dbh->disconnect();

}


sub usage {
    print <<USAGE;
Options:
    -i(--in,--infile) : input file (YAML)
    -d(--dbname)      : database name
    -h(--host)        : host
    --port            : port no
    -u(--user)        : username
    -p(--password)    : password

USAGE

    exit(-1);
}


__END__


=head1 NAME

hd_delete_all.pl - delete all records which table names and IDs are written in a file. 


=head1 VERSION

This documentation refers to hd_delete_all.pl version 0.0.2


=head1 USAGE

    $ hd_delete_all.pl --infile inserted.yml -d mydb -u myuser -p mypasswd


=head1 ARGUMENTS
 
=over 4

=item * -i | --in | --infile

I<< (Required) >> a file name of YAML in which tables and IDs to be deleted are written like the followings:

    ---
    customer:
      - 50
      - 51
    item:
      - 101
      - 102
    purchase:
      - 501
      - 502
      - 503


=item * -d | --dbname

I<< (Required) >> A name of database

=item * -h | --host

I<< (Optional) >> Hostname of database

=item * --port

I<< (Optional) >> Port no.

=item * -u | --user

I<< (Required) >> User name to connect mysql

=item * -p | --password

I<< (Required) >> Password to connect mysql

=item * -v | --verbose

I<< (Optional) >> Display verbose messages.


=back

 
=head1 DESCRIPTION

This scripts deletes all records specified by YAML file, which is generated by hd_insert_bulk.pl (included in this package). Of course manually created YAML file can also be used.
 
 
=head1 BUGS AND LIMITATIONS
 
There are no known bugs in this module. 
Please report problems to Takashi Egawa (C<< egawa.takashi at gmail com >>)
Patches are welcome.


=head1 SEE ALSO

L<Data::HandyGen::mysql>
L<hd_insert_bulk.pl>

 
=head1 AUTHOR
 
Takashi Egawa (C<< egawa.takashi at gmail com >>)
 
 
=head1 LICENCE AND COPYRIGHT
 
Copyright (c)2013 Takashi Egawa (C<< egawa.takashi at gmail com >>). All rights reserved.
 
This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.
 
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 



