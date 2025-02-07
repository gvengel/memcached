#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;

my $server = new_memcached();
test_maxconns($server);

my $ext_path;
if (supports_extstore()) {
    $ext_path = "/tmp/extstore.$$";

    my $server = new_memcached("-m 64 -U 0 -o ext_path=$ext_path:64m");
    test_maxconns($server);
}

sub test_maxconns {
    my $server = shift;

    my $stat_sock = $server->sock;
    my @sockets = ();
    my $num_sockets;
    my $rejected_conns = 0;
    my $stats;
    for (1 .. 1024) {
      my $sock = $server->new_sock;
      if (defined($sock)) {
        push(@sockets, $sock);
        $stats = mem_stats($stat_sock);
        if ($stats->{rejected_connections} > $rejected_conns) {
          $rejected_conns = $stats->{rejected_connections};
          my $buffer = "";
          my $length = 31;
          my $res = recv($sock, $buffer, $length, 0);
          if (not $buffer eq '') {
              is($buffer, "ERROR Too many open connections", "Got expected response from the server");
          }
        }
      }
    }

    for my $s (@sockets) {
        $s->close();
    }

    $stats = mem_stats($stat_sock);
    cmp_ok($stats->{rejected_connections}, '>', '1', 'rejected connections recorded');
    $server->stop;
    $stat_sock->close();
}

done_testing();

END {
    unlink $ext_path if $ext_path;
}
