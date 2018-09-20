#!/usr/bin/perl
#
# Make a knitting Chart
use strict;
use warnings;

use Cairo;
use Getopt::Long;

my $cast_on = 6;
my $rpt_color = 0;
my $odd_only = 0;
my $even_only = 0;
my $test_as = 0;
my $test_gs = 0;
my $first_row = 0;
my $section_only = 0;
my $last_row = 10_000_000;

GetOptions (
    "caston=i" => \$cast_on,
    "as+" => \$test_as,
    "color+" => \$rpt_color,
    "even+" => \$even_only,
    "odd+" => \$odd_only,
    "first-row=i" => \$first_row,
    "last-row=i" => \$last_row,
    "section+" => \$section_only,
    "gs+" => \$test_gs,
);

if ($test_gs) {
    my $inst = shift @ARGV;
    my $ss = [];
    my $sts = $cast_on;
    print "testing get steps with '$inst'\n";
    ($sts, $ss, $inst) = get_steps($sts, $inst);
    print "Get steps returned:\n";
    print "      steps : @{$ss}\n";
    print "      stitches : $sts \n";
    print "      leftover : $inst \n" if (defined $inst);
    exit 0;
}

# unfortunately we have to have the color set when doing section only
# since that tells us when to start outputing chart
if ($section_only) {
    $rpt_color += 1;
}

if ($test_as) {
    my $cmd = shift @ARGV;
    my $ss = [];
    $ss = add_step($ss, $cmd);
    print "Got @{$ss} from add_step\n";
    exit 0;
}


print "Hello Anne! 7\n";
# This is the number of stitches in a line that is being sssk
my $stitches = $cast_on;
# This has each row of steps, the number of stitches per row can vary
my $rows;

my $filename = shift @ARGV;
open (my $fh, "<", $filename) or die "Could not open $filename : $!\n";

my $row_num = 1;
while (my $l = <$fh>) {
    chomp($l);
    my ($row, $instructions) = $l =~ /Round (\d+):\s+(\S.*)$/;
    $instructions =~ s/[\r\n]//g;
    my $steps = [];
    my $i;
#    print "Row: $row, do this '$instructions'\n";
    die "Row computed is $row_num, row parsed $row\n" if ($row != $row_num);
    print "Processing line: '$instructions'\n";
    ($stitches, $steps, $i) = get_steps($stitches, $instructions);
    print "Row : $row:\n";
    print "    Final count is $stitches stitches.\n";
    if (defined $steps) {
        my $nsteps = scalar @{$steps};
        print "    Final steps are @{$steps}.\n";
        if ("\L$steps->[0]" =~ /rhn/) {
            $nsteps -= 1;
        }
        my $actual_steps = 0;
        foreach (@{$steps}) {
            $actual_steps += 1 if ($_ ne "rpt");
        }
        if ( $stitches != $actual_steps) {
            print "   WARNING $nsteps steps but $stitches stitches!\n";
            my $stc_count = $stitches;
            foreach my $sx (@{$steps}) {
                $stc_count -= 1;
                print "$sx\n" if ($stc_count <= 0);
            }
        }
    }
    print "    Line remainder is '$i'\n" if $i ne "";
    print "---------\n";
    push @{$rows}, $steps;
    $row_num += 1;
}
close $fh;
my $total_rows = scalar @{$rows};
print "There are $total_rows rows.\n";
my $shortest = 100;
my $longest = 0;
my %stitch_types;
foreach my $r (@{$rows}) {
    if ($shortest >= scalar @{$r}) {
        $shortest = scalar @{$r};
    }
    if ($longest <= scalar @{$r}) {
        $longest = scalar @{$r};
    }
    foreach my $r2 (@{$r}) {
        my $k = "\L$r2";
        $stitch_types{$k} += 1;
    }
}
print "Shortest row is $shortest stitches, longest is $longest stitches.\n";
print "Types of stitches :\n";
my $total_st = 0;
foreach my $st (keys %stitch_types) {
    print "There are $stitch_types{$st} $st stitches.\n";
    $total_st += $stitch_types{$st};
}
print "$total_st total stitches.\n";


my $PLOT_SIZE = 10;
$PLOT_SIZE = 20 if ($section_only);

my $max_x = (5 + $longest) * $PLOT_SIZE;
my $max_y = (3 + $total_rows) * $PLOT_SIZE;
my $surf = Cairo::SvgSurface->create("knit-chart.svg", $max_x, $max_y);
my $ctx = Cairo::Context->create($surf);
$ctx->select_font_face('arial', 'normal', 'normal');
$ctx->set_font_size(8.5);
$ctx->set_line_width(1.0);
my $center_x = $max_x / 2;
my $cur_y = $max_y - $PLOT_SIZE;
$ctx->set_source_rgb(1, 1, 1);
$ctx->rectangle(0, 0, $max_x, $max_y);
$ctx->fill();
$ctx->set_source_rgb(0, 0, 0);
$row_num = 1;

foreach my $r (@{$rows}) {
    my $width = 0;
    if ($row_num < $first_row) {
        $row_num += 1;
        next;
    }
    next if ($row_num > $last_row);
    if (($row_num & 1) and ($even_only)) {
        $row_num += 1;
        next;
    }
    if ((($row_num & 1) == 0) and ($odd_only)) {
        $row_num += 1;
        next;
    }
    foreach my $s (@{$r}) {
        my $xx = "\L$s";
        next if ($xx =~ /rhn$/);
        next if ($xx =~ /rpt/);
        $width += 1;
        $width += 1 if ($xx eq "kpk");
    }
    $width = $width * $PLOT_SIZE;
    my $start_x = $center_x + (int ($width / 2));
    my $cur_x = $start_x;
    print "row $row_num\n";
    $ctx->move_to($cur_x+(1.1*$PLOT_SIZE), $cur_y+(.7 * $PLOT_SIZE));
    $ctx->set_source_rgb(0, 0, 0);
    $ctx->show_text("$row_num");
    my $saw_repeat = 0;
    foreach my $s (@{$r}) {
        my $xx = "\L$s";
        if ($xx =~ /rhn$/) {
            my ($mv) = $xx =~ /(\d+)_rhn/;
            warn "Shifting row $row_num left by $mv stitches.\n";
            $cur_x -= $PLOT_SIZE * $mv;
            next;
        }
        if ($saw_repeat or ($rpt_color == 0)) {
            $ctx->set_source_rgb(0, 0, 0);
            next if $section_only;
        } else {
            $ctx->set_source_rgb(0, 0, .5);
        }
        if ($xx eq "rpt") {
            $saw_repeat += 1;
            next;
        }
        if ($xx eq "kpk") {
            $cur_x -= $PLOT_SIZE;
            $ctx->rectangle($cur_x, $cur_y, 2 * $PLOT_SIZE, $PLOT_SIZE);
            $ctx->stroke();
        } else {
            $ctx->rectangle($cur_x, $cur_y, $PLOT_SIZE, $PLOT_SIZE);
            $ctx->stroke();
        }
        draw_symbol($ctx, $cur_x, $cur_y, "\L$s", $PLOT_SIZE);
        $cur_x -= $PLOT_SIZE;
    }
    $row_num += 1;
    $cur_y -= $PLOT_SIZE;
}
$surf->show_page();
$surf->write_to_png('knit-chart.png');

print "end of line.\n";
exit 0;
sub draw_symbol {
    my ($ctx, $x, $y, $s, $box) = @_;
    my $half = $box/2;
    return if ($s eq "k1");
    if ($s eq "yo") {
        $ctx->arc($x+$half, $y+$half, .2 * $box, 0, 2 * 3.14159);
        $ctx->stroke();
    } elsif ($s eq "k2tog") {
        $ctx->move_to($x+(.2*$box), $y+(.8 * $box));
        $ctx->line_to($x+(.8*$box), $y+(.2 * $box));
        $ctx->stroke();
    } elsif ($s eq "p1") {
        $ctx->arc($x+$half, $y+$half, .5, 0, 2*3.14159);
        $ctx->stroke();
    } elsif (($s eq "skp") or ($s eq "ssk")) {
        $ctx->move_to($x+(.2 * $box),  $y+ (.2* $box));
        $ctx->line_to($x+(.8*$box), $y+(.8*$box));
        $ctx->stroke();
    } elsif ($s eq "sssk") {
        $ctx->move_to($x+(.2 * $box), $y + (.2 * $box));
        $ctx->line_to($x+(.8 * $box), $y + (.8 * $box));
        $ctx->move_to($x+ $half, $y + $half);
        $ctx->line_to($x + $half, $y + (.8 * $box));
        $ctx->move_to($x+ $half, $y + $half);
        $ctx->line_to($x + (.2 * $box), $y + (.8 * $box));
        $ctx->stroke();
    } elsif ($s eq "k3tog") {
        $ctx->move_to($x+(.8 * $box), $y + (.2 * $box));
        $ctx->line_to($x+(.2 * $box), $y + (.8 * $box));
        $ctx->move_to($x+ $half, $y + $half);
        $ctx->line_to($x + $half, $y + (.8 * $box));
        $ctx->move_to($x+ $half, $y + $half);
        $ctx->line_to($x + (.8 * $box), $y + (.8 * $box));
        $ctx->stroke();
    } elsif ($s eq "sl") {
        $ctx->move_to($x+(.4 * $box), $y + (.2 * $box));
        $ctx->line_to($x+(.15 * $box), $y + (.2 * $box));
        $ctx->line_to($x+(.15 * $box), $y + $half);
        $ctx->line_to($x+(.4 * $box), $y + $half);
        $ctx->line_to($x+(.4 * $box), $y + (.8 * $box));
        $ctx->line_to($x+(.15 * $box), $y + (.8 * $box));
        $ctx->move_to($x+ (.6 * $box), $y + (.2 * $box ));
        $ctx->line_to($x+ (.6 * $box), $y + (.8 * $box ));
        $ctx->line_to($x+ (.85 * $box), $y + (.8 * $box ));
        $ctx->stroke();
    } elsif ($s eq "sk2p") {
        $ctx->move_to($x+(.2*$box), $y+(.8*$box));
        $ctx->line_to($x+$half, $y+(.2*$box));
        $ctx->line_to($x+(.8*$box), $y+(.8*$box));
        $ctx->move_to($x+$half, $y+(.2*$box));
        $ctx->line_to($x+$half, $y+(.8*$box));
        $ctx->stroke();
    } elsif ($s eq "kpk") {
        $ctx->arc($x+$box, $y+$half, .5, 0, 2*3.14159);
        $ctx->move_to($x+(.7*$box), $y+(.2 * $box));
        $ctx->line_to($x+(.7*$box), $y+(.8 * $box));
        $ctx->move_to($x+(1.3*$box), $y+(.2 * $box));
        $ctx->line_to($x+(1.3*$box), $y+(.8 * $box));
        $ctx->stroke();
    } elsif ($s eq "p&k") {
        $ctx->arc($x+(.4*$box), $y+$half, .5, 0, 2*3.14159);
        $ctx->move_to($x+(.7*$box), $y+(.2*$box));
        $ctx->line_to($x+(.7*$box), $y+(.8*$box));
        $ctx->stroke();
    } elsif ($s eq "kp") {
        $ctx->arc($x+(.6*$box), $y+$half, .5, 0, 2*3.14159);
        $ctx->move_to($x+(.3*$box), $y+(.2 * $box));
        $ctx->line_to($x+(.3*$box), $y+(.8 * $box));
        $ctx->stroke();
    } elsif ($s eq "m1") {
        $ctx->move_to($x+$half, $y+(.3*$box));
        $ctx->line_to($x+$half, $y+(.7*$box));
        $ctx->move_to($x+(.3*$box), $y+$half);
        $ctx->line_to($x+(.7*$box), $y+$half);
        $ctx->stroke();
    } elsif ($s eq "kb") {
        $ctx->move_to($x+(.3*$box), $y+(.8*$box));
        $ctx->curve_to($x+(.3*$box), $y+(.8*$box), $x+$box, $y+$half, $x+$half, $y+2);
        $ctx->move_to($x+(.7*$box), $y+(.8*$box));
        $ctx->curve_to($x+(.7*$box), $y+(.8*$box), $x, $y+$half, $x+$half, $y+2);
        $ctx->stroke();
    } else {
        print "Couldn't plot $s yet\n";
    }
}


sub get_steps {
    my ($sts, $i) = @_;
    my $count = 0;
#    print "GET_STEPS ENTER :: $i\n";
    my $working_steps = [];
    if (substr($i, 0, 1) eq '(') {
        my $repeat_steps;
        my $result;
        ($sts, $repeat_steps, $i) = get_steps($sts, substr($i, 1));
#        print "repeat steps got : @{$repeat_steps}\n";
        my $rpt;
        ($rpt, $i) = get_repeat($i);
        ($sts, $working_steps) = insert_steps($working_steps, 
                                        $repeat_steps, $sts, $rpt);
        if ($i eq "") {
#            print " ... returning (process repeat):\n";
#            print "        steps =  @{$working_steps}\n";
#            print "       stitches = $sts'\n";
            return ($sts, $working_steps, $i);
        }
    } 
    my $cmd = "";
    while ($i ne "") {
        my $c = substr($i, 0, 1);
        $i = substr($i, 1);
        $count += 1;
        if ($c =~ /[\s,)]/) {
            if ($cmd ne "") {
                $working_steps = add_step($working_steps, $cmd);
#                print "Add_step returned @{$working_steps} for $cmd \n";
                $cmd = "";
            }
            if ($c eq ')') {
#                print " ... returning (process steps):\n";
#                print "        steps =  @{$working_steps}\n";
#                print "       stitches = $sts'\n";
                return ($sts, $working_steps, $i);
            }
        } elsif ($c eq '(') {
#            print " ... get_steps() --> Enter repeat processing\n";
            my $r_steps = [];
            ($sts, $r_steps, $i) = get_steps($sts, $i);
#            print "      repeat steps are @{$r_steps}\n";
            my $rpt;
            ($rpt, $i) = get_repeat($i);
#            print "      number of repeats is $rpt\n";
#            print "      steps before : @{$working_steps}\n";
            ($sts, $working_steps) = insert_steps($working_steps, 
                                            $r_steps, $sts, $rpt);
#            print "      steps after : @{$working_steps}\n";
        } else {
            $cmd .= $c;
        }
    }
    if ($cmd ne "") {
        $working_steps = add_step($working_steps, $cmd);
#        print "Add_step returned @{$working_steps} for $cmd \n";
    }
#    print " ... returning (end of line):\n";
#    print "        steps =  @{$working_steps}\n";
#    print "       stitches = $sts'\n";
    return ($sts, $working_steps, $i);
}

# get_repeat - this subroutine takes a string and returns a repeat value of
# -1 for "all" or a positive number of repeats, and a string with the repeat
# value consumed.
sub get_repeat {
    my ($i) = @_;
#    print "Get repeat\n";
    my $rpt;
    my $count = 0;
    foreach my $c (split(//, $i)) {
        $count += 1;
        if ($c eq '*') {
            $rpt = -1;
            last;
        }
        last if ($c eq '}');
        next if ($c eq '{');
        $rpt .= $c;
    }
#    print "Get repeat returning $rpt and '", substr($i, $count), "'\n";
    return ($rpt, substr($i, $count));
}

#        $sts = insert_steps($new_steps, $repeat_steps, $sts, $rpt)
# insert_steps - take the steps passed, and insert 'n' copies of them and update
# the number of available stitches.
sub insert_steps {
    my ($cur_steps, $repeat_steps, $sts, $rpt) = @_;
    my @steps;
    @steps = @{$cur_steps};
    if ($rpt == -1) {
#        print "GLOBAL REPEAT: @{$repeat_steps}\n";
        my $local_sts = $sts;
        while ($local_sts > 0) {
#            print "Initial stitch counts ($local_sts exist, $sts net)\n";
            foreach my $s (@{$repeat_steps}) {
                my $s2 = "\L$s";
                push @steps, $s;
                if ($s2 eq "yo5") {
                    $sts += 5;
                } elsif ($s2 eq "yo2") {
                    $sts += 2;
                } elsif ($s2 eq "yo") {
                    $sts += 1;
                } elsif ($s2 =~ /k2tog/) {
                    $sts -= 1;
                    $local_sts -= 2;
                } elsif ($s2 =~ /k3tog/) {
                    $sts -= 2;
                    $local_sts -= 3;
                } elsif ($s2 =~ /sssk/) {
                    $sts -= 2;
                    $local_sts -= 3;
                } elsif ($s2 =~ /skp/) {
                    $sts -= 1;
                    $local_sts -= 2;
                } elsif ($s2 =~ /ssk/) {
                    $sts -= 1;
                    $local_sts -= 2;
                } elsif ($s2 =~ /sk2p/) {
                    $sts -= 2;
                    $local_sts -= 3;
                } elsif ($s2 =~ /m1/) {
                    $sts += 1;
                } elsif ($s2 eq "kpk") {
                    $sts += 1;
                    $local_sts -= 2;
                } elsif ($s2 eq "p&k") {
                    $sts += 1;
                    $local_sts -= 1;
                } elsif ($s2 eq "kp") {
                    $sts += 1;
                    $local_sts -= 1;
                } elsif ($s2 eq "sl") {
                    print "***** PROCESSED SL *******\n";
                    $local_sts -= 1;
                } else {
                    my $consume = 1;
                    if ($s2 =~ /^k/) {
                        ($consume) = $s2 =~ /k(\d+)/;
                        $consume = 1 if (not defined $consume);
                    }
                    die "Failed to parse $s2!!!" if (($s2 eq "k4") and ($consume != 4));
                    $local_sts -= $consume;
                }
            }
            push @steps, "rpt";
#            print "Passed through the loop once ($local_sts exist, $sts net).\n";
            if ($local_sts < -1) {
                warn "Over consuming stitches, repeat broken.\n";
                print "         *** Broken Repeat! ($local_sts) ***\n";
            }
        }
    } else {
        while ($rpt > 0) {
            $rpt -= 1;
            foreach my $s (@{$repeat_steps}) {
                my $s2 = "\L$s";
                push @steps, $s;
#                if ($s2 eq "yo5") {
#                    $sts += 5;
#                } elsif ($s2 eq "yo2") {
#                    $sts += 2;
#                } elsif ($s2 eq "yo") {
#                    $sts += 1;
#                } elsif ($s2 =~ /k2tog/) {
#                    $sts -= 1;
#                } elsif ($s2 =~ /skp/) {
#                    $sts -= 1;
#                } elsif ($s2 =~ /sk2p/) {
#                    $sts -= 2;
#                } elsif ($s2 =~ /m1/) {
#                    $sts += 1;
#                } elsif ($s2 eq "kpk") {
#                    $sts += 1;
#                } elsif ($s2 eq "p&k") {
#                    $sts += 1;
#                } elsif ($s2 eq "kp") {
#                    $sts += 1;
#                } 
            }
        }
    }
    return ($sts, \@steps);
}
#           $working_steps = add_step($working_steps, $sts, $cmd);
# add_step - add the singlular stitches from possibly a repeated stitch
sub add_step {
    my ($steps, $cmd) = @_;
    my $t = "\L$cmd";

#    print "ADD_STEP:: Enter with $cmd\n";
    if (($t eq "k2tog") or ($t eq "kb") or ($t eq "kpk")) {
        push @{$steps}, $cmd;
        return $steps;
    }
    if (($t eq "p&k") or ($t eq "pk")) {
        push @{$steps}, "P&K";
        return $steps;
    }
    
    if ($t eq "sl") {
        push @{$steps}, "sl";
        return $steps;
    }

    if (($t eq "kp") or ($t eq "k&p")) {
        push @{$steps}, "KP";
        return $steps;
    }

    if ($t eq "kpkpk") {
        push @{$steps}, "K1";
        push @{$steps}, "P1";
        push @{$steps}, "K1";
        push @{$steps}, "P1";
        push @{$steps}, "K1";
        return $steps;
    }

    if ($t eq "k3tog") {
        push @{$steps}, "k3tog";
        return $steps;
    }
    
    if ($t eq "sssk") {
        push @{$steps}, "sssk";
        return $steps;
    }
        

    if ($t =~ /^k/) {
        my ($num) = $t =~ /k(\d+)/;
        if (not defined ($num)) {
            warn "$t didn't parse a number\n";
        }
        for (my $i = 0; $i < $num; $i += 1) {
            push @{$steps}, "K1";
        }
        return $steps;
    }

    if ($t =~ /^p/) {
        my ($num) = $t =~ /p(\d+)/;
        for (my $i = 0; $i < $num; $i += 1) {
            push @{$steps}, "P1";
        }
        return $steps;
    }
    if ($t =~ /^yo/) {
        my ($num) = $t =~ /yo(\d+)/;
        $num = 1 if (not defined $num);
        for (my $i = 0; $i < $num; $i += 1) {
            push @{$steps}, "yo";
        }
        return $steps;
    }
    push @{$steps}, $cmd;
    return $steps;
}

