ad_library {

    PRETTI routines used for Project Reporting Evaluation and Track Task Interpretation
    With Hints Of GANTT Activity Network Task Tracking (PRETTI WHO GANTT)
    Project Activity Network Evaluation By Reporting Low Float Paths In Fast Tracks
    @creation-date 11 Feb 2014
    @cvs-id $Id:
    @Copyright (c) 2014 Benjamin Brink
    @license GNU General Public License 3, see project home or http://www.gnu.org/licenses/gpl-3.0.en.html
    @project home: http://github.com/tekbasse/accounts-finance
    @address: po box 20, Marylhurst, OR 97036-0020 usa
    @email: tekbasse@yahoo.com

    Temporary comment about git commit comments: http://xkcd.com/1296/
}

namespace eval acc_fin {}

ad_proc -public acc_fin::pretti_equation_vars {
} {
    Returns a list of value triplets, where each value pair consists of 1. a variable name used in pretti custom equation feature,  2. a human legible variable equivalent, and 3. a brief definition of the variable
} {
    set vars_lol [list [list 0 path_len "Number of different activities in path"] \
                      [list 1 path_len_w_coefs "Number of activities in path"] \
                      [list 2 act_cp_ratio "Ratio of activities in path that are also in Critical Path"] \
                      [list 3 cost_ratio "Cost ratio: cost of path / cost of project"] \
                      [list 4 on_critical_path_p "1 if path is Critical Path, otherwise 0"] \
                      [list 5 duration_ratio "Duration ratio: duration of path / duration of Critical Path"] \
                      [list 6 path_counter "A path's sequence number from Critical Path based on PRETTI index"] \
                      [list 7 act_count_median "Median count of unique activities on a path."] \
                      [list 8 act_count_max "Max count of unqiue activities on a path."] \
                      [list 9 a_sig_path_p "1 if path contains at least one activity that is above the median count (act_path_count_median), otherwise 0"] ]
    return $vars_lol
}

ad_proc -private acc_fin::pretti_log_create {
    table_tid
    action_code
    action_title
    entry_text
    {user_id ""}
    {instance_id ""}
} {
    Log an entry for a pretti process. Returns unique entry_id if successful, otherwise returns empty string.
} {
    set id ""
    set status [qf_is_natural_number $table_tid]
    if { $status } {
        if { $entry_text ne "" } {
            if { $instance_id eq "" } {
                set instance_id [ad_conn package_id]
            }
            if { $user_id eq "" } {
                set user_id [ad_conn user_id]
            }
            set id [db_nextval qaf_id_seq]
            set trashed_p 0
            set nowts [dt_systime -gmt 1]
            set action_code [qf_abbreviate $action_code 38]
            set action_title [qf_abbreviate $action_title 78]
            db_dml qaf_process_log_create { insert into qaf_process_log
                (id,table_tid,instance_id,user_id,trashed_p,name,title,created,last_modified,log_entry)
                values (:id,:table_tid,:instance_id,:user_id,:trashed_p,:action_code,:action_title,:nowts,:nowts,:entry_text) }
            ns_log Notice "acc_fin::pretti_log_create.46: posting to qaf_process_log: action_code ${action_code} action_title ${action_title} '$entry_text'"
        } else {
            ns_log Warning "acc_fin::pretti_log_create.48: attempt to post an empty log message has been ignored."
        }
    } else {
        ns_log Warning "acc_fin::pretti_log_create.51: table_tid '$table_tid' is not a natural number reference. Log message '{$entry_text}' ignored."
    }
    return $id
}

ad_proc -public acc_fin::pretti_log_read {
    table_tid
    {max_old "1"}
    {user_id ""}
    {instance_id ""}
} {
    Returns any new log entries as a list via util_user_message, otherwise returns most recent max_old number of log entries.
    Returns empty string if no entry exists.
} {
    set return_lol [list ]
    set alert_p 0
    set nowts [dt_systime -gmt 1]
    set valid1_p [qf_is_natural_number $table_tid] 
    set valid2_p [qf_is_natural_number $table_tid]
    if { $valid1_p && $valid2_p } {
        if { $instance_id eq "" } {
            set instance_id [ad_conn package_id]
        }
        if { $user_id eq "" } {
            set user_id [ad_conn user_id]
        }
        set return_lol [list ]
        set last_viewed ""
        set alert_msg_count 0
        set viewing_history_p [db_0or1row qaf_process_log_viewed_last { select last_viewed from qaf_process_log_viewed where instance_id = :instance_id and table_tid = :table_tid and user_id = :user_id } ]
        set last_viewed [string range $last_viewed 0 18]
        if { $last_viewed ne "" } {

            set entries_lol [db_list_of_lists qaf_process_log_read_new { 
                select id, name, title, log_entry, last_modified from qaf_process_log 
                where instance_id = :instance_id and table_tid =:table_tid and last_modified > :last_viewed order by last_modified desc } ]

            ns_log Notice "acc_fin::pretti_log_read.80: last_viewed ${last_viewed}  entries_lol $entries_lol"

          if { [llength $entries_lol ] > 0 } {
                set alert_p 1
                set alert_msg_count [llength $entries_lol]
                foreach row $entries_lol {
                    set message_txt "[lc_time_system_to_conn [string range [lindex $row 4] 0 18]] [lindex $row 3]"
                    set last_modified [lindex $row 4]
                    ns_log Notice "acc_fin::pretti_log_read.79: last_modified ${last_modified}"
                    util_user_message -message $message_txt
                    ns_log Notice "acc_fin::pretti_log_read.88: message '${message_txt}'"
                }
                set entries_lol [list ]
            } 
        }
        
        set max_old [expr { $max_old + $alert_msg_count } ]
        set entries_lol [db_list_of_lists qaf_process_log_read_one { 
            select id, name, title, log_entry, last_modified from qaf_process_log 
            where instance_id = :instance_id and table_tid =:table_tid order by last_modified desc limit :max_old } ]
        foreach row [lrange $entries_lol $alert_msg_count end] {
            set message_txt [lindex $row 2]
            append message_txt " ([lindex $row 1])"
            append message_txt " posted: [lc_time_system_to_conn [string range [lindex $row 4] 0 18]]\n "
            append message_txt [lindex $row 3]
            ns_log Notice "acc_fin::pretti_log_read.100: message '${message_txt}'"
            lappend return_lol $message_txt
        }

        # set new view history time
        if { $viewing_history_p } {
            # last_modified ne "", so update
            db_dml qaf_process_log_viewed_update { update qaf_process_log_viewed set last_viewed = :nowts where instance_id = :instance_id and table_tid = :table_tid and user_id = :user_id }
        } else {
            # create history
            set id [db_nextval qaf_id_seq]
            db_dml qaf_process_log_viewed_create { insert into qaf_process_log_viewed
                  ( id, instance_id, user_id, table_tid, last_viewed )
                values ( :id, :instance_id, :user_id, :table_tid, :nowts ) }
        }
    }
    return $return_lol
}


ad_proc -public acc_fin::pert_omp_to_strict_dc {
    optimistic
    most_likely
    pessimistic
} {
    Creates a curve in PRETTI table format representing strict characteristics of 
    a PERT expected time function (Te), where 
    Te = ( o + 4 * m + p ) / 6 and o = optimistic time, m = most likely time, and p = pessimistic time.
    This 3 point curve has lower limit (o), upper limit (p) and median (m). 
} {
#    ns_log Notice "acc_fin::pert_omp_to_strict_dc.24: optimistic $optimistic most_likely $most_likely pessimistic $pessimistic"
    # nomenclature of inputs  statistics:
    # set median $most_likely
    # set minimum $optimistic
    # set maximum $pessimistic
    set curve_lists [list ]
    lappend curve_lists [list y x]
    set one_sixth [expr { 1. / 6. } ]
    set point_list [list $optimistic $one_sixth]
    lappend curve_lists $point_list
    set point_list [list $most_likely [expr { 4. / 6. } ] ]
    lappend curve_lists $point_list
    set point_list [list $pessimistic $one_sixth]
    lappend curve_lists $point_list
    return $curve_lists
}

ad_proc -public acc_fin::pert_omp_to_normal_dc {
    optimistic
    most_likely
    pessimistic
    {n_points "24"}
} {
    Creates a normal distribution curve in PRETTI table format representing characteristics of 
    a PERT expected time function (Te), where 
    Te = ( o + 4 * m + p ) / 6 and o = optimistic time, m = most likely time, and p = pessimistic time.
    The normal distribution curve has lower limit (o), upper limit (p) and median (m). 
    Regression tests at accounts-finance/tcl/test/pretti-test-procs.tcl suggests 24 points minimum for a practical representation of a curve.
    18 point is about the absolute minimum practical amount for passing a clear majority of regression tests to within 1%. 5 is lowest number of points accepted.
    See also acc_fin::pert_omp_to_stric_dc for a 3 point curve that matches project management representation of the Time expected curve.
} {
    ns_log Notice "acc_fin::pert_omp_to_normal_dc.23: starting"
    ns_log Notice "acc_fin::pert_omp_to_normal_dc.24: optimistic $optimistic most_likely $most_likely pessimistic $pessimistic n_points $n_points"
    # nomenclature of inputs  statistics:
    # set median $most_likely
    # set minimum $optimistic
    # set maximum $pessimistic
    set n_points [f::max [expr { int( $n_points ) } ] 5]
    set n_areas  [expr { int( $n_points - 1 ) } ]

    #set pi 3.14159265358979
    set pi [expr { atan2( 0. , -1. ) } ]
    #set e 2.718281828459  see exp()
    set sqrt_2pi [expr { sqrt( 2. * $pi ) } ]
    set sqrt_2 [expr { sqrt( 2. ) } ]
    set optimistic [expr { $optimistic * 1. } ]
    set most_likely [expr { $most_likely * 1. } ]
    set pessimistic [expr { $pessimistic * 1. } ]
    # Symetric calculations use indexed arrays to swap between tails.
    # Index of:
    # 0 = left tail
    # 1 = right tail

    # Build a curve using Normal Distribution calculations as a base

    # Split the curve into two tails, in case med - min value does not equal max - med.

    # Left tail represents minimum to median.
    # So, create a standard_deviation for left side by assuming curve is symmetric:
    # set std_dev_left [expr { sqrt( 2 * pow( $minimum - $median , 2) + 4 * pow( $median - $median , 2) ) } ]
    # resolves to:
    # set std_dev_left [expr { sqrt( 2 * pow( $minimum - $median , 2)  ) } ]
    # which further reduces to:

    set std_dev(0) [expr { $sqrt_2 * abs( $most_likely - $optimistic ) } ]
#    set variance(0) [expr { pow( $std_dev(0) , 2. ) } ]
#    set precision(0) [expr { 1. / $std_dev(0) } ]
#    set precision2(0) [expr { 1. / pow( $std_dev(0) , 2. ) } ]
    set precision(0) 1.
    set precision2(0) [expr { pow( $precision(0) , 2. ) } ]
    # Right tail represents median to maximum.
    set std_dev(1) [expr { $sqrt_2 * abs( $pessimistic - $most_likely ) } ]
#    set variance(1) [expr { 2. * pow( $std_dev(1) , 2. ) } ]
#    set precision(1) [expr { 1. / $std_dev(1) } ]
#    set precision2(1) [expr { 1. / pow( $std_dev(1) , 2. ) } ]
    set precision(1) 1.
    set precision2(1) [expr { pow( $precision(1) , 2. ) } ]

#    ns_log Notice "acc_fin::pert_omp_to_normal_dc.42: std_dev_left $std_dev(0) std_dev_right $std_dev(1)"
    # f(x) is the normal distribution function. x = 0 at $median
    
    # for each section of the curve divided into p_count() ie ($n_areas /2) sections of approximately equal area.
    # since each tail has area circa 0.5, delta_area is circa 0.5 / p_count()
    # given 2 points on curve f(x) = y, (x0,y0), (x1,y1) defines an approximate area, where 
    # delta_area = 0.5 * ( y0 + y1 ) ( x1 - x0 )   and
    # delta_area = 0.5 / p_count

    # given x0,y0, n_areas,  if y1 is estimated as y0 - y_range / p_count
    # x1 is approx 1 / ( n_areas * ( y0 + y1) ) 
    # if y1 is approximated equal to y0
    # x1 is approx 1 / (n_areas * 2 * y0 )
    
    # f(x) = k * pow( $e , -0.5 * pow( $x - $median , 2. ) )
    # where k = 1. / sqrt( 2. * $pi )
    # where x  is -2. * std_dev_left to 2. * std_dev_right
    # and value at x is :
    # if x < 0
    # $minimum + sigma f( $x from -2. * $std_dev_left to x = 0 ) * p_count()
    # if x => 0
    # $median + sigma f( $x from x = 0 to 2. * $std_dev_right ) * p_count()
    
    # Determine x points. Start with 0 to get critical area near distribution peak.

    # if there is an odd number of areas, use the extra one on the longer side
    if { $std_dev(0) > $std_dev(1) } {
        set p_count(1) [expr { int( $n_areas / 2. ) } ]
        set p_count(0) [expr { $n_areas - $p_count(1) } ]
    } else {
        set p_count(0) [expr { int( $n_areas / 2. ) } ]
        set p_count(1) [expr { $n_areas - $p_count(0) } ]
    }
    
    # create tails and their analogs
 #   ns_log Notice "acc_fin::pert_omp_to_normal_dc.83: n_areas $n_areas p_count(0) $p_count(0) p_count(1) $p_count(1)"
    # from median to double standard deviation to approximate OMP calculations

    # left tail, assume symmetric, but calculate to reduce error
    set y_range_arr(0) [expr { ( $most_likely - $optimistic ) } ]
    set fx_limit(0) $optimistic
    # right tail, assume symmetric
    set y_range_arr(1) [expr { ( $pessimistic - $most_likely ) } ]
    set fx_limit(1) $pessimistic

    foreach ii [list 0 1] {
        set x_larr($ii) [list ]
        set y_larr($ii) [list ]
        set a_larr($ii) [list ]
        set da_larr($ii) [list ]
        set fx_larr($ii) [list ]
        # standard deviation = sigma

        # range of x over f(x) is -2. * std_dev_left to 2. * std_dev_right
        # let's break the areas somewhat equally, or to increase with each iteration
        # x2 can be approximated all sorts of ways. 
        # A linear progression is used.
        # An integration eq over a partial derivative might be more appropriate later.
        
        set a 0.
        set a_prev $a
    
        set x1 0.
#        set y1 [expr { exp( -0.5 * pow( $x1 , 2. ) ) / $sqrt_2pi } ] 
#        set y1 [expr { exp( -0.5 * pow( $x1 , 2. ) / $variance($ii) ) / ( $std_dev($ii) * $sqrt_2pi ) } ] 
#        set y1 [expr { exp( -0.5 * pow( $x1 , 2. ) / $variance($ii) ) / $sqrt_2pi } ] 
        set y1 [expr { $precision($ii) * exp( -0.5 * $precision2($ii) * pow( $x1 , 2. ) ) / $sqrt_2pi } ] 

        # estimate delta_x and a:
        set block_count [lindex [qaf_triangular_numbers [expr { $p_count($ii) - 0 } ]] end]
        set numerator 0

#        ns_log Notice "acc_fin::pert_omp_to_normal_dc.90: ii $ii p_count($ii) $p_count($ii) block_count $block_count numerator $numerator std_dev($ii) $std_dev($ii)" 

        # first point in tail:
        set step_021 [expr { $numerator / $block_count } ]
        lappend y_larr($ii) $y1
        lappend x_larr($ii) $x1

        # Calculations are from x = 0 to x = std_dev
        # Therefore, left tail needs flipped afterward

        # At the end of the loop, calculate the last point manually.
        # ns_log Notice "acc_fin::pert_omp_to_normal_dc.99: i '' x1 '$x1' delta_x '' y2 '' y1 '$y1' f_x '' numerator $numerator step_021 $step_021"
        for {set i 0 } { $i < $p_count($ii) } { incr i } {
            set numerator [expr { $numerator + 1. } ]

            set step_021 [expr { $numerator / $block_count + $step_021 } ]            
            set x2 [expr { $std_dev($ii) * $step_021 } ]
            set delta_x [expr { $x2 - $x1 } ]
            # Calculate y2 = f(x) = using the normal probability density function
#            set y2 [expr { exp( -0.5 * pow( $x2 , 2. ) ) / $sqrt_2pi } ] 
#            set y2 [expr { exp( -0.5 * pow( $x2 , 2. ) / $variance($ii) ) / ( $std_dev($ii) * $sqrt_2pi ) } ] 
#            set y2 [expr { exp( -0.5 * pow( $x2 , 2. ) / $variance($ii) ) / $sqrt_2pi } ] 
            set y2 [expr { $precision($ii) * exp( -0.5 * $precision2($ii) * pow( $x2 , 2. ) ) / $sqrt_2pi } ] 

            # Calculate area under normal distribution curve.
            set a [expr { $a + $delta_x * ( $y2 + $y1 ) / 2. } ]
            set delta_a [expr { $a - $a_prev } ]

            if { $ii } {
                # Right tail
                set f_x [expr { $most_likely + $y_range_arr(1) * $step_021 } ]
            } else {
                # Left tail
                set f_x [expr { $most_likely - $y_range_arr(0) * $step_021 } ]
            }
#            ns_log Notice "acc_fin::pert_omp_to_normal_dc.100: i $i x2 '$x2' x1 '$x1' delta_x '$delta_x' y2 '$y2' y1 '$y1' f_x '$f_x' numerator $numerator step_021 $step_021"
            lappend x_larr($ii) $x2
            lappend y_larr($ii) $y2
            lappend a_larr($ii) $a
            lappend da_larr($ii) $delta_a
            lappend fx_larr($ii) $f_x
            set y1 $y2
            set x1 $x2
            set a_prev $a

        }
        # Test area under normal distribution curve.
        set a_arr($ii) [f::sum $da_larr($ii)]

    }

    # ns_log Notice "acc_fin::pert_omp_to_normal_dc.116: a_arr(0) $a_arr(0) a_arr(1) $a_arr(1)"
    # tail areas must be equal.
    if { $a_arr(1) != $a_arr(0) } {
        ns_log Notice "acc_fin::pert_omp_to_normal_dc.118: a_arr(0) of $a_arr(0) != a_arr(1) $a_arr(1)"
    }

    # build final curve

    # column titles
    set curve_lists [list ]
    lappend curve_lists [list y x]

    # left tail, reverse order
#### Here a point is subtracted, apparently because the last area is empty.. why??
    # p_count() is point length. minus 1 to count from 0 to one less than p_count
    set i_count [expr { $p_count(0) - 1 } ]
    for {set i $i_count} { $i > -1 } {incr i -1} {
        set f_x [lindex $fx_larr(0) $i]
        set delta_a [lindex $da_larr(0) $i]
#        set a [expr { $a + $delta_a } ]
        set a [lindex $a_larr(0) $i]
 #       ns_log Notice "acc_fin::pert_omp_to_normal_dc.234: i '$i' delta_a '$delta_a' a '$a' f_x '$f_x'"
        set point_list [list $f_x $delta_a]
        lappend curve_lists $point_list
    }
    # last item this tail
    # mark index of this last point, because we will be modifying it 
    set median_range_idx [llength $curve_lists]
    incr median_range_idx -1

    # right tail, append
    # ref 1

#    set i_count [expr { $p_count(1) - 1 } ]
    for {set i 0} { $i < $p_count(1) } {incr i } {
        set f_x [lindex $fx_larr(1) $i]
        set delta_a [lindex $da_larr(1) $i]
#        set a [expr { $a + $delta_a } ]
        set a [lindex $a_larr(1) $i]
 #       ns_log Notice "acc_fin::pert_omp_to_normal_dc.243: i '$i' delta_a '$delta_a' a '$a' f_x '$f_x'"
        set point_list [list $f_x $delta_a]
        lappend curve_lists $point_list
    }

    # combine the tails at x = 0
    # combining these areas reduces curve area count by one too many. 
    #set a0 [expr { [lindex $a_larr(0) 0] + [lindex $a_larr(1) 0] } ]
    set a0 [lindex $a_larr(1) 0]

    set a_curve [expr { $a_arr(0) + $a_arr(1) } ]
    set a0_test [expr { 1. - $a_curve + $a0 } ]

    if { $a0_test > 0. } {
        # straightforward adjustments work
        set a_new $a0_test

    } else {
        # $a0_test is negative, apparently because a_curve > 1
        # renormalize a0 to compensate and keep a0 in meridian area:
        # $a_curve / 1.  = $a_curve = a_curve ratio:
        # if a0 is negative, make it positive and expand a0 by a ratio of the curve area to 1
        set a_new [expr { abs($a0) * $a_curve } ]
    }
    set median_list [list $most_likely $a_new]

#    set median_end_idx [expr { $median_range_idx } ]
#    ns_log Notice "acc_fin::pert_omp_to_normal_dc.351: a0 $a0 a_curve $a_curve a0_test $a0_test a_new $a_new median_range_idx $median_range_idx median_end_idx $median_end_idx"
#    set curve_lists [lreplace $curve_lists $median_range_idx $median_end_idx $median_list]
    # extra point has already been removed,
    set curve_lists [lreplace $curve_lists $median_range_idx $median_range_idx $median_list]


# 
    #set f_x [lindex $fx_larr(1) $i]
#    set f_x $pessimistic
#    set delta_a [lindex $da_larr(1) $i_count]
#    set a [expr { $a + $delta_a } ]
#    ns_log Notice "acc_fin::pert_omp_to_normal_dc.246: i '$i' delta_a '$delta_a' a '$a' f_x '$f_x'"
#    set point_list [list $f_x $delta_a]
#    lappend curve_lists $point_list

    # remove header for point count
    # but add a point because each item is an area, and there are area_count + 1 points
    set points_count [expr { [llength $curve_lists] - 1 } ]
    if { $points_count != $n_areas } {
        ns_log Warning "acc_fin::pert_omp_to_normal_dc.288: curve has $points_count areas instead of requested $n_areas areas (add one for points ie area boundaries). curve_lists $curve_lists"
    } else {
  #      ns_log Notice "acc_fin::pert_omp_to_normal_dc.289: curve_lists $curve_lists"
    }
    return $curve_lists
}


ad_proc -public acc_fin::pretti_geom_avg_of_curve {
    curve_lol
    {correction "0"}
} {
    Given a curve with x and y columns, finds the geometric average determined by: (y1*x1 + y2*x2 .. yN*xN ) / sum(x1..xN). Correction is a value, usually -1, or +1 applied to a formula to adjust bias in a sample population as in N/(N - 1) or N/(N + 1).  n - 1 is sometimes referred to a Bessel's correction. Default is no correction. More about Bessel's correction at: http://en.wikipedia.org/wiki/Bessel%27s_correction
} {
    # This is a generalization of the PERT Time-expected function
    set constants_list [list y x]
    # get first row of titles
    set title_list [lindex $curve_lol 0]
    set y_idx [lsearch -exact $title_list "y"]
    set x_idx [lsearch -exact $title_list "x"]
    set geometric_avg ""
    if { $y_idx > -1 && $x_idx > -1 } {
        set x_list [list ]
        set numerator_list [list ]
        foreach point_list [lrange $curve_lol 1 end] {
            set x [lindex $point_list $x_idx]
            set y [lindex $point_list $y_idx]
            lappend x_list $x
            lappend  numerator_list [expr { $x * $y * 1. } ]
        }
        set x_sum [f::sum $x_list ]
        if { $x_sum != 0. } {
            set numerator [f::sum $numerator_list ]
            set geometric_avg [expr { $numerator / $x_sum } ]
            set n [expr { [llength $x_list] * 1. } ]
            set n_corr [expr { $n + $correction } ]
            if { $correction ne "0" && $n_corr != 0. } {
                ns_log Notice "acc_fin::pretti_geom_avg_of_curve.383: geometric_avg $geometric_avg"
                set geometric_avg [expr { $geometric_avg * $n / $n_corr } ]
                ns_log Notice "acc_fin::pretti_geom_avg_of_curve.385: new geometric_avg $geometric_avg"
            }
        } else {
            ns_log Notice "acc_fin::pretti_geom_avg_of_curve.170: divide by zero caught for x_sum. numerator $numerator"
        }
    } else {
        ns_log Notice "acc_fin::pretti_geom_avg_of_curve.178: y_idx $y_idx x_idx $x_idx"
    }

    return $geometric_avg
}


ad_proc -public acc_fin::pretti_type_flag {
    table_lists
} {
    Guesses which type of pretti table
} {
    #upvar $table_lists_name table_lists
    # page flags as pretti_types:
    #  p in positon 1 = PRETTI app specific
    #  p1  scenario
    #  p2  task network (unique tasks and their dependencies)
    #  p3  task types (can also have dependencies)
    #  dc distribution curve
    #  p4  PRETTI report (output)
    #  p5  PRETTI db report (output) (similar format to  p3, where each row represents a path, but in p5 all paths are represented)
    #  dc Estimated project duration distribution curve (can be used to create other projects)

    # get first row
    set title_list [lindex $table_lists 0]
    set type_return ""
    # check for type p1 separate from the other cases, because the table is specified differently from other cases.
    set p(p1) 0
    set name_idx [lsearch -exact $title_list "name" ]
    set value_idx [lsearch -exact $title_list "value" ]
#    ns_log Notice "acc_fin::pretti_columns_list.390 name_idx $name_idx value_idx $value_idx title_list '$title_list'"
    if { $name_idx > -1 && $value_idx > -1 } {
        # get name column
        set name_list [list ]
#        ns_log Notice "acc_fin::pretti_columns_list.400 table_lists '$table_lists'"
        foreach row [lrange $table_lists 1 end] {
            lappend name_list [lindex $row $name_idx]
        }
#        ns_log Notice "acc_fin::pretti_columns_list.401 name_list '$name_list'"
        # check name_list against p1 required names. 
        # All required names need to be in list, but not all list names are required.
        set p(p1) 1
        # required names in check_list
        set check_list [acc_fin::pretti_columns_list "p1" 1 ]
#        ns_log Notice "acc_fin::pretti_columns_list.402 check_list $check_list"
        foreach check $check_list {
            set p(p1) [expr { $p(p1) && ( [lsearch -exact $name_list $check] > -1 ) } ]
#            ns_log Notice "acc_fin::pretti_columns_list.404 check $check p(p1) $p(p1)"
        }

    }
    if { $p(p1) } {
        set type_return "p1"
#        ns_log Notice "acc_fin::pretti_columns_list.410 type = p1"
    } else {
        # filter other p table types by required minimums first
        set type_list [list "p2" "p3" "p4" "p5" "dc"]
#        ns_log Notice "acc_fin::pretti_columns_list.414 type not p1. check for $type_list"
        foreach type $type_list {
            set p($type) 1
            set check_list [acc_fin::pretti_columns_list $type 1]
#            ns_log Notice "acc_fin::pretti_type_flag.58: type $type check_list $check_list"
            foreach check $check_list {
                set p($type) [expr { $p($type) && ( [lsearch -exact $title_list $check] > -1 ) } ]
#                ns_log Notice "acc_fin::pretti_type_flag.60: check $check p($type) $p($type)"
            }
        }
        
        # how many types might this table be?
        set type1_p_list [list ]
        foreach type $type_list {
            if { $p($type) } {
                lappend type1_p_list $type
            }
        }
#        ns_log Notice "acc_fin::pretti_type_flag.69: type1_p_list '${type1_p_list}'"
        set type_count [llength $type1_p_list]
        if { $type_count > 1 } {
            # choose one
            if { $p(p2) && $p(p3) && $type_count == 2 } {
                if { [lsearch -exact $title_list "aid_type" ] > -1 } {
                    set type_return "p2"
                } elseif { [lsearch -exact $title_list "type" ] > -1 } {
                    set type_return "p3"
                } 
            } else {
                set type3_list [list ]
                # Which type best meets full list of implemented column names?
                foreach type $type1_p_list {
                    set name_list [acc_fin::pretti_columns_list $type 0]
                    set name_list_count [llength $name_list]
                    set exists_count 0
                    foreach name $name_list {
                        if { [lsearch -exact $title_list $name] > -1 } {
                            incr exists_count
                        }
                    }
                    if { $name_list_count > 0 } {
                        set type_pct_list [list $type [expr { ( $exists_count * 1. ) / ( $name_list_count * 1. ) } ] ]
                        lappend type3_list $type_pct_list
                    } 
                }
                set type3_list [lsort -real -index 1 -decreasing $type3_list]
#                ns_log Notice "acc_fin::pretti_type_flag.450: type1_p_list '${type1_p_list}'"
#                ns_log Notice "acc_fin::pretti_type_flag.453: type3_list '$type3_list'"
                set type_return [lindex [lindex $type3_list 0] 0]
            }
        } else {
            # append is used here in case no type meets the criteria, an empty string is returned
            append type_return [lindex $type1_p_list 0]
        }
    }
            
    return $type_return
}

ad_proc -private acc_fin::pretti_columns_list {
    type
    {required_only_p "0"}
} {
    Returns a list of column names used by pretti table type. If required_only_p is 1, only returns the required columns for specified type. Reserved words are not included in the list.
} {
    set sref $type
    append sref $required_only_p
    switch -exact $sref {
        p10 {
            # p1 PRETTI Scenario
            # consists of a "name" and "value" column, with names of:
            #      activity_table_tid
            #      activity_table_name      name of table containing task network
            #      period_unit          measure of time used in task duration etc.
            #      time_dist_curve_name      a default distribution curve name when a task type doesn't reference one.
            #      time_dist_curve_tid      a default distribution curve table_id, dist_curve_name overrides dist_curve_dtid
            #      cost_dist_curve_name      a default distribution curve name when a task type doesn't reference one.
            #      cost_dist_curve_tid      a default distribution curve table_id, dist_curve_name overrides dist_curve_dtid
            #      with_factors_p  defaults to 1 (true). Set to 0 (false) if any factors in p3 are to be ignored.
            #                           This option is useful to intercede in auto factor expansion to add additional
            #                           variation in repeating task detail. (deprecated by auto expansion of nonexisting coefficients).
            #      time_probability_moment A percentage (0..1) along the (cumulative) distribution curve. defaults to 0.5
            #      cost_probability_moment A percentage (0..1) along the (cumulative) distribution curve. defaults to "", which defaults to same as time_probability_moment
            #set ret_list \[list name value\]
            ### adding max_concurrent and max_overlap_pct but not sure if these have been coded for use yet..
            set ret_list [list activity_table_tid activity_table_name task_types_tid task_types_name time_dist_curve_name time_dist_curve_tid cost_dist_curve_name cost_dist_curve_tid time_est_short time_est_median time_est_long time_probability_moment cost_est_low cost_est_median cost_est_high cost_probability_moment db_format index_equation ]
        }
        p11 {
            #set ret_list \[list name value\]
            set ret_list [list activity_table_tid ]
        }
        p20 {
            # p2 Task Network
            #      activity_ref           reference for an activity, a unique task id, using "activity" to differentiate between table_id's tid 
            #                             An activity reference is essential a function as in f() with no attributes,
            #                             However, there is room to grow this by extending a function to include explicitly set paramemters
            #                             within the function, similar to how app-model handles functions aka vectors
            #                             The multiple of an activity is respresented by a whole number followed by an "*" 
            #                             with no spaces between (when spaces are used as an activity delimiter), or
            #                             with spaces allowed (when commas or another character is used as an activity delimiter.)
            #                
            #      aid_type               activity type from p3
            #      dependent_tasks        direct predecessors , activity_ref of activiites this activity depends on.
            #      name                   defaults to type's name (if exists else blank)
            #      description            defaults to type's description (if exists else blank)
            #      max_concurrent         defaults to type's max_concurrent 
            #      max_overlap_pct     defaults to type's max_overlap_pct021
            
            #      time_est_short         estimated shortest duration. (Lowest statistical deviation value)
            #      time_est_median        estimated median duration. (Statistically, half of deviations are more or less than this.) 
            #      time_est_long          esimated longest duration. (Highest statistical deviation value.)
            #      time_dist_curve_tid Use this distribution curve instead of the time_est short, median and long values
            #                             Consider using a variation of task_type as a reference
            #      time_dist_curv_eq  Use this distribution curve equation instead.
            
            #      cost_est_low           estimated lowest cost. (Lowest statistical deviation value.)
            #      cost_est_median        estimated median cost. (Statistically, half of deviations are more or less than this.)
            #      cost_est_high          esimage highest cost. (Highest statistical deviation value.)
            #      cost_dist_curve_tid Use this distribution curve instead of equation and value defaults
            #      cost_dist_curv_eq  Use this distribution curve equation. 
            #
            #      RESERVED columns:
            #      _tCurveRef             integer reference to time curve in time_clarr and   time duration estimate at time_probability_moment in t_est_arr
            #      _cCurveRef             integer reference to cost curve in cost_clarr and   cost duration estimate at cost_probability_moment in c_est_arr
            #      _coef                  integer coefficient for use with calculations that require remembering the coefficient when multiple of an activity is referenced.
            #      _tDcSource             source of time curve used from acc_fin::curve_import
            #      _cDcSource             source of cost curve used from acc_fin::curve_import
            set ret_list [list activity_ref dependent_tasks aid_type name description max_concurrent max_overlap_pct time_est_short time_est_median time_est_long time_dist_curve_tid time_dist_curve_name time_probability_moment cost_est_low cost_est_median cost_est_high cost_dist_curve_tid cost_dist_curve_name cost_probability_moment]

        }
        p21 {
            set ret_list [list activity_ref dependent_tasks]
        }
        p30 {
            # p3 Task Types:   
            #      type
            #      dependent_types      Other dependent types required by this type. (possible reference collisions. type_refs != activity_refs.)
            #
            #####                       dependent_types should be checked against activity_dependents' types 
            #                           to confirm that all dependencies are satisified.
            #      name
            #      description
            #      max_concurrent       (as an integer, blank = no limit)
            #      max_overlap_pct021  (as a percentage from 0 to 1, blank = 1)
            #
            #      RESERVED columns:
            #      _tCurveRef             integer reference to time curve in time_clarr and   time duration estimate at time_probability_moment in t_est_arr
            #      _cCurveRef             integer reference to cost curve in cost_clarr and   cost duration estimate at cost_probability_moment in c_est_arr
            #      _tDcSource             source of time curve used from acc_fin::curve_import
            #      _cDcSource             source of cost curve used from acc_fin::curve_import

            set ret_list [list type dependent_tasks dependent_types name description max_concurrent max_overlap_pct time_dist_curve_name time_dist_curve_tid cost_dist_curve_name cost_dist_curve_tid time_est_short time_est_median time_est_long cost_est_low cost_est_median cost_est_high ]
        }
        p31 {
            set ret_list [list type]
            # if changing p3 or p2 lists, see also constants_woc_list in this file.
        }
        p40 {
            # each column is track_{number} and generated by code so not used in this context

            # p4 Display modes
            #  
            #  tracks within n% of CP duration, n represented as %12100 or a duration of time as total lead slack
            #  tracks w/ n fixed count closest to CP duration. A n=1 shows CP track only.
            #  tracks that contain at least 1 CP track 
            set ret_list [list track_1]
        }
        p41 {
            # each column is track_{number} and generated by code so not used in this context
            set ret_list [list track_1]
        }
        p50 {
            # each row is a cell, in format of detailed PRETTI internal output. See code. All columns are required to reproduce output to p4 (including p4 comments).

            set ret_list [list activity_ref path_act_counter path_counter dependencies_q cp_q significant_q popularity waypoint_duration activity_time direct_dependencies activity_cost waypoint_cost]
        }
        p51 {
            # each row is a cell, in format of detailed PRETTI internal output. See code. 
            set ret_list [list activity_ref path_act_counter path_counter dependencies_q cp_q significant_q popularity waypoint_duration activity_time direct_dependencies activity_cost waypoint_cost path_col activity_seq dependents_count dep_act_seq ]
        }
        dc0 {
            # dc2 distribution curve table
            #                   Y         where Y = f(x) and f(x) is a 
            #                             probability mass function ie probability density function as a distribution
            #                             http://en.wikipedia.org/wiki/Probability_mass_function
            #                             http://en.wikipedia.org/wiki/Probability_density_function
            #                         aka http://en.wikipedia.org/wiki/Discrete_probability_distribution#Discrete_probability_distribution
            #                             The discrete values are the values of Y included in the table
            
            #                    X        Where X = the probability of Y.
            #                             These can be counts of a sample or a frequency.  When the table is saved,
            #                             the total area under the distribution is normalized to 1.
            
            #                   label     Where label represents the value of Y at x. This is a short phrase or reference
            #                             that identifies a boundary point in the distribution.
            # A three point (short/median/long or low/median/high) estimation curve can be respresented as
            # a discrete set of six points:  minimum median median median median maximum 
            # of standard bell curve probabilities (outliers + standard deviation).
            # Thereby allowing *_probability_moment variable to be used in estimates with lower statistical resolution.
            set ret_list [list y x label]
        }
        dc1 {
            set ret_list [list y x]
        }
        default {
            ns_log Notice "acc_fin::pretti_columns_list (242): bad reference sref '$sref'. Returning blank list."
            set ret_list [list ]
        }
    }
    return $ret_list
}


ad_proc -public acc_fin::pretti_table_to_html {
    pretti_lol
    comments
} {
    Interprets a saved p4 pretti output table into html table.
} {
    # process table by building columns in row per html TABLE TR TD tags
    # pretti_lol consists of first row:
    # track_1 track_2 track_3 ... track_N
    # subsequent rows:
    # cell_r1c1 cell_r1c2 cell_r1c3 ... cellr1cN
    # ...
    # cell_rMc1 cell_rMc2 cell_rMc3 ... cellrMcN
    # for N tracks of a maximum of M rows.
    # Each cell is an activity.
    # Each column is a track
    # Track_1 is CP

    # empty cells have empty string value.
    # other cells will contain comment format from acc_fin::scenario_prettify
    # "$activity "
    # "t:[lindex $track_list 7] "
    # "ts:[lindex $track_list 6] "
    # "c:[lindex $track_list 9] "
    # "cs:[lindex $track_list 10] "
    # "d:($depnc_larr(${activity})) "
    # "<!-- [lindex $track_list 4] [lindex $track_list 5] --> "

    set column_count [llength [lindex $pretti_lol 0]]
    set row_count [llength $pretti_lol]
    incr row_count -1
    
    # values to be extracted from comments:
    # max_act_count_per_track and cp_duration_at_pm 
    # Other parameters could be added to comments for changing color scheme/bias
    set color_sig_mask_idx ""
    regexp -- {[^a-z\_]?color_sig_mask_idx[\ \=\:]([0-7])[^0-7]} $comments scratch color_sig_mask_idx
    if { [ad_var_type_check_number_p $color_sig_mask_idx] && $color_sig_mask_idx > -1 && $color_sig_mask_idx < 8 } {
        # do nothing
    } else {
        # set default
        set color_sig_mask_idx 3
    }
    set color_oth_mask_idx ""
    regexp -- {[^a-z\_]?color_oth_mask_idx[\ \=\:]([0-7])[^0-7]} $comments scratch color_oth_mask_idx
    if { [ad_var_type_check_number_p $color_oth_mask_idx] && $color_oth_mask_idx > -1 && $color_oth_mask_idx < 8 } {
        # do nothing
    } else {
        # set default
        set color_oth_mask_idx 5
    }

    set colorswap_p ""
    regexp -- {[^a-z\_]?colorswap_p[\ \=\:]([0-1])[^0-1]} $comments scratch colorswap_p
    if { [ad_var_type_check_number_p $colorswap_p] && $colorswap_p > -1 && $colorswap_p < 2 } {
        # do nothing
    } else {
        # set default
        set colorswap_p 0
    }
    
    set max_act_count_per_track $row_count
    regexp -- {[^a-z\_]?max_act_count_per_track[\ \=\:]([0-9]+)[^0-9]} $comments scratch max_act_count_per_track
    if { $max_act_count_per_track == 0 } {
        set max_act_count_per_track $row_count
    }
    regexp -- {[^a-z\_]?cp_duration_at_pm[\ \=\:]([0-9]+)[^0-9]} $comments scratch cp_duration_at_pm
    if { $cp_duration_at_pm == 0 } {
        # Calculate cp_duration_at_pm manually, using track_1 (cp track)
        foreach row [lrange $pretti_lol 1 end] {
            set cell [lindex $row 0]
            if { $cell ne "" } {
                regexp -- {ts:([0-9\.]+)[^0-9]} $cell scratch test_num
            }
        }
        if { [ad_var_type_check_number_p $test_num] && $test_num > 0 } {
            set cp_duration_at_pm $test_num
        }
    }
    
    # determine list of CP activities
    set cp_list [list ]
    foreach row [lrange $pretti_lol 1 end] {
        set cell [lindex $row 0]
        if { $cell ne "" } {
            # activity is not Title of activity, but activity_ref
            if {  [regexp -- {^([^\ ]+) t:} $cell scratch activity_ref ] } {
                lappend cp_list $activity_ref
            }
        }
    }
    
    # Coloring and formating will be interpreted 
    # based on values provided in comments, 
    # data from track_1 and table type (p4) for maximum flexibility.   
    
    # table cells need to indicate a relative time length in addition to dependency. check
    
    set title_formatting_list [list ]
    foreach title [lindex $pretti_lol 0] {
        lappend title_formatting_list [list style "font-style: bold;"]
    }
    set table_attribute_list [list ]
    set table_formating_list [list ]
    lappend table_formatting_list $title_formatting_list
    
    # build formatting colors

    set hex_list [list 0 1 2 3 4 5 6 7 8 9 a b c d e f]
    set bin_list [list 000 100 010 110 001 101 011 111]

    set color_sig_mask [lindex $bin_list $color_sig_mask_idx]
    set color_sig_mask_list [split $color_sig_mask ""]
    set color_oth_mask [lindex $bin_list $color_oth_mask_idx]
    set color_oth_mask_list [split $color_oth_mask ""]

    set row_nbr 1
    set k1 [expr { $max_act_count_per_track / $cp_duration_at_pm } ]
    set k2 [expr {  16. / $column_count } ]
    ns_log Notice "acc_fin::pretti_table_to_html.845: k1 $k1 k2 $k2 color_sig_mask_list '${color_sig_mask_list}' color_oth_mask_list '${color_oth_mask_list}'"
    set pretti4html_lol [lrange $pretti_lol 0 0]

    foreach row [lrange $pretti_lol 1 end] {
        set row4html_list [list ]
        set row_formatting_list [list ]
        set odd_row_p [expr { ( $row_nbr / 2. ) != int( $row_nbr / 2 ) } ]

        set cell_nbr 0
        foreach cell $row {
            set activity_time_expected ""

            if { [regexp -- {t:([0-9\.]+)[^0-9]} $cell scratch activity_time_expected ] } {
                set row_size [f::max [expr { int( $activity_time_expected * $k1 ) } ] 1 ]
            } else {
                set row_size 1
            }
            if { [regexp -- {<!--[^0-9]([0-9\.]+)[^0-9]([0-9\.]+)[^0-9]-->} $cell scratch on_a_sig_path_p popularity ] } {
                # on_a_sig_path_p specified
            } else {
                set on_a_sig_path_p 0
                set popularity 0
            }

            # CP in highest contrast (yellow ff9) for the column: ff9 ee9 ff9 ee9 ff9
            # CP-alt means on_a_sig_path_p
            # CP-alt in alternating lt magenta to lt green: 99f .. 9f9 of lowering contrast to f77
            # others in alternating medium green/blue:   66f .. 6f6
            # contrast decreases on up to 50%
            # f becomes e for even rows..

            # to build cell color:
            # contrast_adj
            # color_mask_idx
            # 
            ns_log Notice "acc_fin::pretti_table_to_html.862: row_nbr '${row_nbr}' cell_nbr '${cell_nbr}' odd_row_p '${odd_row_p}' row_size '${row_size}' activity_time_expected '${activity_time_expected}'"

            # cell_nbr eq 0  is CP
            set on_a_sig_path_p [expr { $on_a_sig_path_p || ( $cell_nbr == 0 ) } ]

            if { $on_a_sig_path_p } {
                # significant, base color pink f0f
                # see color_sig_mask

                # set color1 and color2 based on activity count, blue lots of count, green is less count
                # max $popularity is column_count
                # create 2 values to be used with masks, 1 is most significant, 0 less significant
                set color_mask_list $color_sig_mask_list
                set dec_nbr_val [f::max 16 [expr { int( $popularity * $k2 ) } ]]
                set c(1) $dec_nbr_val
                set c(0) [expr { 16 - $dec_nbr_val } ]
                
            } else {
                # other, base color green 0f0
                # see color_oth_mask

                # constrast_step is number from 1 to 7, with 7 being most popular, 1 least popular
                # create 2 values to be used with masks, 1 is most sig, 0 less significant
                set color_mask_list $color_oth_mask_list
                set dec_nbr_val [f::max 7 [f::min 1 [expr { int( $popularity * $k2 / 2. ) } ] ]]
                set c(0) $dec_nbr_val
                set c(1) [expr { int( ( 8 - $dec_nbr_val ) / 2. ) + 4 } ]
            }

            set colorhex ""

            if { $odd_row_p } {
                incr c(1) -1
            }

            foreach digit $color_mask_list {
                append colorhex [lindex $hex_list $c($digit)]
                append colorhex "f"

            }

            ns_log Notice "acc_fin::pretti_table_to_html.915: colorhex '$colorhex' on_a_sig_path_p ${on_a_sig_path_p} popularity $popularity dec_nbr_val ${dec_nbr_val} c(0) '$c(0)' c(1) '$c(1)' color_mask_list '${color_mask_list}'"
            set cell_formatting [list style "background-color: #${colorhex};"]
            if { $cell eq "" } {
                set cell "&nbsp;"
            }
            lappend row4html_list $cell
            lappend row_formatting_list $cell_formatting
            incr cell_nbr
        }
        lappend pretti4html_lol $row4html_list
        lappend table_formatting_lists $row_formatting_list
        incr row_nbr
    }
    
    # html
    set pretti_html "<h3>Computation report</h3>"
    append pretti_html [qss_list_of_lists_to_html_table $pretti4html_lol $table_attribute_list $table_formatting_lists]
    return $pretti_html
}


ad_proc -public acc_fin::larr_set {
    larr_name
    data_list
} {
    Assigns a data_list to an index in array larr_name 
    in a manner that minimizes memory footprint. 
    If the list already exists (exactly) in the array, 
    it returns the existing index, 
    otherwise it assignes a new index in array and 
    a new index of array is returned. 
    This procedure helps reduce memory overhead 
    for indexes with lots of list data.
} {
    upvar 1 ${larr_name} larr
    # If memory issues exist even after using this proc, one can further compress the array by applying a dictionary storage technique.
    # It may be possible to use the list as an index and gain from tcl internal handling for example.
    # hmm. Initial tests suggest this array(list) works, but might not be practical to store references..
    set indexes_list [array names larr]
    set icount [llength $indexes_list]
    set idx_last [expr { $icount - 1 } ]
#    ns_log Notice "acc_fin::larr_ste.945: larr_name $larr_name indexes_list '$indexes_list' icount '$icount'"
    if { $icount > 0 } {
        set i 0
        set index [lindex $indexes_list $i]
#        ns_log Notice "acc_fin::larr_ste.949: index '$index' i $i"
        while { $i < $idx_last && $larr($index) ne $data_list } {
            incr i
            set index [lindex $indexes_list $i]
#            ns_log Notice "acc_fin::larr_ste.953: index '$index' i $i"
        }
#        ns_log Notice "acc_fin::larr_ste.955: index '$index' i $i"
        if { $larr($index) ne $data_list } {
            set i $icount
            set larr($icount) $data_list
        } 
    } else {
        set i $icount
        set larr($icount) $data_list
    }
    if { [llength $data_list] == 0 } { 
        ns_log Warning "acc_fin::larr_set.956: empty data_list request in larr ${larr_name}."
    } 
#    ns_log Notice "acc_fin::larr_set.958: ${larr_name}\(${i}\) '$larr($i)' data_list '${data_list}'"
    return $i
}

ad_proc -private acc_fin::p_load_tid {
    constants_list
    constants_required_list
    p_larr_name
    tid
    {p3_larr_name ""}
    {instance_id ""}
    {user_id ""}
} {
    loads array_name with p2 or p3 style table for use with internal code
} {
    upvar 1 $p_larr_name p_larr
    upvar 1 time_clarr time_clarr
    upvar 1 cost_clarr cost_clarr
    upvar 1 type_t_curve_arr type_t_curve_arr
    upvar 1 type_c_curve_arr type_c_curve_arr
    # need to pass p1_arr defaults for p2 dc processing
    upvar 1 p1_arr p1_arr
    # following are not upvar'd because the cache is mainly useless after proc ends
    #    upvar 1 tc_cache_larr tc_cache_larr
    #    upvar 1 cc_cache_larr cc_cache_larr
    # following are not upvar'd because these are temporary arrays for loading list representations of curves
    #    upvar 1 tc_larr tc_larr
    #    upvar 1 cc_larr cc_larr

    if { $instance_id eq "" } {
        set instance_id [ad_conn package_id]
    }
    if { $user_id eq "" } {
        set user_id [ad_conn user_id]
    }
    set table_type "p3"
    set type_tcurve_list [list ]
    set type_ccurve_list [list ]
    if { $p3_larr_name ne ""} {
        upvar 1 $p3_larr_name p3_larr
        # p_larr must be a p2 table
        set table_type "p2"
    }

    # set table defaults
    foreach column $constants_list {
        set p_larr($column) [list ]
    }

    # load table into array of lists {{a b c} {1 2 3} {4 5 6}} becomes p_larr(a) {1 4}, p_larr(b) {2 5}, p_larr(c) {3 6}
    qss_tid_columns_to_array_of_lists $tid p_larr $constants_list $constants_required_list $instance_id $user_id
    set i_max -1
    set p2_types_exist_p 0
    set p2_type_column_exists_p 0
    set p3_types_exist_p 0
    set p3_type_column_exists_p 0

    if { $table_type eq "p3" } {
        # if 'type' column exists, then p_larr is a p3 table
        set p3_type_column_exists_p [info exists p_larr(type)]
        if { $p3_type_column_exists_p } {
            set i_max [llength $p_larr(type) ]
            set p3_types_exist_p [expr { [llength $p_larr(type)] > 0 } ]
        } 
    } elseif { $table_type eq "p2" } {
        # i_max is activity_ref length
        set p2_actref_column_exists_p [info exists p_larr(activity_ref)]
        if { $p2_actref_column_exists_p } {
            set i_max [llength $p_larr(activity_ref)]
        }       
        set p2_type_column_exists_p [info exists p_larr(aid_type)]
        if { $p2_type_column_exists_p } {
            set p2_types_exist_p [expr { [llength $p_larr(aid_type)] > 0 } ]
        } 
    }

    if { $p3_types_exist_p && $table_type eq "p2" } {
        ns_log Warning "acc_fin::p_load_tid.1005: table_type ${table_type} and p3_types_exist_p $p3_types_exist_p is an unexpected condition. Investigate."
        # Is there any reason why p3 rows cannot be defined in a p2 table?
        # Recall, p3 loads curves , whereas p2 possibly references existing curves from p3.
        # if okay to have p3 rows in a p2, then logic changes to (p2 || p3) vs. p3 for this proc.
    }
    
    # filter user input that is going to be used as references in arrays:
    if { $p3_type_column_exists_p } {
        set p_larr(type) [acc_fin::list_filter alphanum $p_larr(type) $p_larr_name "type"]
        if { [info exists p_larr(dependent_tasks) ] } {
            set p_larr(dependent_tasks) [acc_fin::list_filter alphanumlist $p_larr(dependent_tasks) $p_larr_name "dependent_tasks"]
        }
    }
    if { $p2_type_column_exists_p } {
        set p_larr(aid_type) [acc_fin::list_filter alphanum $p_larr(aid_type) $p_larr_name "type"]
    }
    
    
    # import curves referenced in the table
    set p_larr(_tCurveRef) [list ]
    set p_larr(_cCurveRef) [list ]
    set p_larr(_coef) [list ]

    if { $table_type eq "p3" && $p3_type_column_exists_p } {
        # table_type is p3
        set p3_t_dc_tid_exists_p [info exists p_larr(time_dist_curve_tid) ]
        set p3_t_dc_name_exists_p [info exists p_larr(time_dist_curve_name) ]
        set p3_t_est_short_exists_p [info exists p_larr(time_est_short) ]
        set p3_t_est_median_exists_p [info exists p_larr(time_est_median) ]
        set p3_t_est_long_exists_p [info exists p_larr(time_est_long) ]

        set p3_c_dc_tid_exists_p [info exists p_larr(cost_dist_curve_tid) ]
        set p3_c_dc_name_exists_p [info exists p_larr(cost_dist_curve_name) ]
        set p3_c_est_low_exists_p [info exists p_larr(cost_est_low) ]
        set p3_c_est_median_exists_p [info exists p_larr(cost_est_median) ]
        set p3_c_est_high_exists_p [info exists p_larr(cost_est_high) ]


        # load any referenced curves
        
        ns_log Notice "acc_fin::p_load_tid.1021: for ${p_larr_name} i_max ${i_max}"
        for {set i 0} {$i < $i_max} {incr i} {
            
            set type [lindex $p_larr(type) $i]
            
            # time curve
            set time_dist_curve_tid ""
            set time_dist_curve_name ""
            set time_est_short ""
            set time_est_median ""
            set time_est_long ""
            if { $p3_t_dc_name_exists_p } {
                set time_dist_curve_name [lindex $p_larr(time_dist_curve_name) $i]
                ns_log Notice "acc_fin::p_load_tid.1081: for ${p_larr_name} i $i q1"
            }
            if { $time_dist_curve_name ne "" } {
                set time_dist_curve_tid [qss_tid_from_name $time_dist_curve_name ]
                ns_log Notice "acc_fin::p_load_tid.1085: for ${p_larr_name} i $i q2"
            } 
            if { $p3_t_dc_tid_exists_p && $time_dist_curve_tid eq "" } {
                set time_dist_curve_tid [lindex $p_larr(time_dist_curve_tid) $i]
                ns_log Notice "acc_fin::p_load_tid.1089: for ${p_larr_name} i $i q3"
            }
            # set defaults
            set constants_list [acc_fin::pretti_columns_list dc]
            foreach constant $constants_list {
                set tc_larr($constant) ""
            }

            if { $time_dist_curve_tid ne "" } {
                if { ![info exists tc_cache_larr(x,${time_dist_curve_tid}) ] } {
                    set constants_required_list [acc_fin::pretti_columns_list dc 1]
                    qss_tid_columns_to_array_of_lists ${time_dist_curve_tid} tc_larr $constants_list $constants_required_list $instance_id $user_id
                    # add to temporary cache
                    foreach constant $constants_list {
                        set tc_cache_larr($constant,${time_dist_curve_tid}) $tc_larr($constant)
                    }
                }
                #tc_larr(x), tc_larr(y) and optionally tc_larr(label) where _larr refers to an array where each value is a list of column data by row 1..n
                foreach constant $constants_list {
                    set tc_larr($constant) $tc_cache_larr($constant,${time_dist_curve_tid})
                }
            }
            if { $p3_t_est_short_exists_p } {
                set time_est_short [lindex $p_larr(time_est_short) $i]
            }

            if { $p3_t_est_median_exists_p } {
                set time_est_median [lindex $p_larr(time_est_median) $i]
            }
            if { $p3_t_est_long_exists_p } {
                set time_est_long [lindex $p_larr(time_est_long) $i]
            }
            # import curve given all the available curve choices
            ns_log Notice "acc_fin::p_load_tid.1118: for ${p_larr_name} i $i time_est_short '${time_est_short}' time_est_median '${time_est_median}' time_est_long '${time_est_long}' type_tcurve_list '${type_tcurve_list}' tc_larr(x) '$tc_larr(x)' tc_larr(y) '$tc_larr(y)' tc_larr(label) '$tc_larr(label)'"
            set curve_list [acc_fin::curve_import $tc_larr(x) $tc_larr(y) $tc_larr(label) $type_tcurve_list $time_est_short $time_est_median $time_est_long $time_clarr($p1_arr(_tCurveRef)) ]
            set tcurvenum [acc_fin::larr_set time_clarr $curve_list]
            if { $tcurvenum eq "" } {
                ns_log Notice "acc_fin::p_load_tid.1120: for ${p_larr_name} i $i type $type _tCurveRef is blank for curve_list '${curve_list}'."
            }

            # cost curve
            set cost_dist_curve_tid ""
            set cost_dist_curve_name ""
            set cost_est_low ""
            set cost_est_median ""
            set cost_est_high ""
            if { $p3_c_dc_name_exists_p } {
                set cost_dist_curve_name [lindex $p_larr(cost_dist_curve_name) $i]
            }
            if { $cost_dist_curve_name ne "" } {
                set cost_dist_curve_tid [qss_tid_from_name $cost_dist_curve_name ]
            } 
            if { $p3_c_dc_tid_exists_p && $cost_dist_curve_tid eq "" } {
                set cost_dist_curve_tid [lindex $p_larr(cost_dist_curve_tid) $i]
            }
            # set defaults
            foreach constant $constants_list {
                set cc_larr($constant) ""
            }

            if { $cost_dist_curve_tid ne "" } {
                set constants_list [acc_fin::pretti_columns_list dc]
                if { ![info exists cc_cache_larr(x,${cost_dist_curve_tid}) ] } {
                    set constants_required_list [acc_fin::pretti_columns_list dc 1]
                    qss_tid_columns_to_array_of_lists ${cost_dist_curve_tid} cc_larr $constants_list $constants_required_list $instance_id $user_id
                    # add to input tid cache
                    foreach constant $constants_list {
                        set cc_cache_larr($constant,${cost_dist_curve_tid}) $cc_larr($constant)
                    }
                }
                #cc_larr(x), cc_larr(y) and optionally cc_larr(label) where _larr refers to an array where each value is a list of column data by row 1..n                
                foreach constant $constants_list {
                    set cc_larr($constant) $cc_cache_larr($constant,${cost_dist_curve_tid})
                }
            }
            if { $p3_c_est_low_exists_p } {
                set cost_est_low [lindex $p_larr(cost_est_low) $i] 
            }
            if { $p3_c_est_median_exists_p } {
                set cost_est_median [lindex $p_larr(cost_est_median) $i] 
            }
            if { $p3_c_est_high_exists_p } {
                set cost_est_high [lindex $p_larr(cost_est_high) $i]
            }
            # import curve given all the available curve choices
            ns_log Notice "acc_fin::p_load_tid.1168: for ${p_larr_name} i $i cost_est_low '${cost_est_low}' cost_est_median '${cost_est_median}' cost_est_high '${cost_est_high}' type_ccurve_list '${type_ccurve_list}' cc_larr(x) '$cc_larr(x)' cc_larr(y) '$cc_larr(y)' cc_larr(label) '$cc_larr(label)'"
            set curve_list [acc_fin::curve_import $cc_larr(x) $cc_larr(y) $cc_larr(label) $type_ccurve_list $cost_est_low $cost_est_median $cost_est_high $cost_clarr($p1_arr(_cCurveRef)) ]
            set ccurvenum [acc_fin::larr_set cost_clarr $curve_list]
            if { $ccurvenum eq "" } {
                ns_log Notice "acc_fin::p_load_tid.1188: for ${p_larr_name} i $i type $type _cCurveRef is blank for curve_list '${curve_list}'."
            }


            # add curve references for both time and cost. 
            lappend p_larr(_tCurveRef) $tcurvenum
            lappend p_larr(_cCurveRef) $ccurvenum
            ns_log Notice "acc_fin::p_load_tid.1106: for ${p_larr_name} added: p_larr(_tCurveRef) $tcurvenum p_larr(_cCurveRef) $ccurvenum"
            # Since this is a p3_larr, create pointer arrays for use with p2_larr
            if { $type ne "" } {
                ns_log Notice "acc_fin::p_load_tid.1121: type_t_curve_arr($type) $tcurvenum"
                set type_t_curve_arr($type) $tcurvenum
                ns_log Notice "acc_fin::p_load_tid.1123: type_c_curve_arr($type) $ccurvenum"
                set type_c_curve_arr($type) $ccurvenum
            } 
            
        }
        # end for i, $i < $i_max
        
    } elseif { $table_type eq "p2" } {
        # table_type is p2 
        # p2 defined curves are loaded in context of higher level of complexity
        
        
        # table_type is p2
        
        set p2_t_dc_tid_exists_p [info exists p_larr(time_dist_curve_tid) ]
        set p2_t_dc_name_exists_p [info exists p_larr(time_dist_curve_name) ]
        set p2_t_est_short_exists_p [info exists p_larr(time_est_short) ]
        set p2_t_est_median_exists_p [info exists p_larr(time_est_median) ]
        set p2_t_est_long_exists_p [info exists p_larr(time_est_long) ]
        
        set p2_c_dc_tid_exists_p [info exists p_larr(cost_dist_curve_tid) ]
        set p2_c_dc_name_exists_p [info exists p_larr(cost_dist_curve_name) ]
        set p2_c_est_low_exists_p [info exists p_larr(cost_est_low) ]
        set p2_c_est_median_exists_p [info exists p_larr(cost_est_median) ]
        set p2_c_est_high_exists_p [info exists p_larr(cost_est_high) ]
        
        ns_log Notice "acc_fin::p_load_tid.1227: for ${p_larr_name} i_max ${i_max}"
        for {set i 0} {$i < $i_max} {incr i} {
            
            # time curve
            set time_dist_curve_tid ""
            set time_dist_curve_name ""
            set time_est_short ""
            set time_est_median ""
            set time_est_long ""
            if { $p2_t_dc_name_exists_p } {
                set time_dist_curve_name [lindex $p_larr(time_dist_curve_name) $i]
                ns_log Notice "acc_fin::p_load_tid.1238: for ${p_larr_name} i $i q1"
            }
            if { $time_dist_curve_name ne "" } {
                set time_dist_curve_tid [qss_tid_from_name $time_dist_curve_name ]
                ns_log Notice "acc_fin::p_load_tid.1242: for ${p_larr_name} i $i q2"
            } 
            if { $p2_t_dc_tid_exists_p && $time_dist_curve_tid eq "" } {
                set time_dist_curve_tid [lindex $p_larr(time_dist_curve_tid) $i]
                ns_log Notice "acc_fin::p_load_tid.1246: for ${p_larr_name} i $i q3"
            }
            # set defaults
            set constants_list [acc_fin::pretti_columns_list dc]
            foreach constant $constants_list {
                set tc_larr($constant) ""
            }
            
            if { $time_dist_curve_tid ne "" } {
                if { ![info exists tc_cache_larr(x,${time_dist_curve_tid}) ] } {
                    set constants_required_list [acc_fin::pretti_columns_list dc 1]
                    qss_tid_columns_to_array_of_lists ${time_dist_curve_tid} tc_larr $constants_list $constants_required_list $instance_id $user_id
                    # add to temporary cache
                    foreach constant $constants_list {
                        set tc_cache_larr($constant,${time_dist_curve_tid}) $tc_larr($constant)
                    }
                }
                #tc_larr(x), tc_larr(y) and optionally tc_larr(label) where _larr refers to an array where each value is a list of column data by row 1..n
                foreach constant $constants_list {
                    set tc_larr($constant) $tc_cache_larr($constant,${time_dist_curve_tid})
                }
            }
            if { $p2_t_est_short_exists_p } {
                set time_est_short [lindex $p_larr(time_est_short) $i]
            }
            
            if { $p2_t_est_median_exists_p } {
                set time_est_median [lindex $p_larr(time_est_median) $i]
            }
            if { $p2_t_est_long_exists_p } {
                set time_est_long [lindex $p_larr(time_est_long) $i]
            }
            
            # import curve given all the available curve choices

            if { $p2_types_exist_p && $p2_type_column_exists_p } {
                # aid_type exists, so include option in curve_import   
                # load aid_type referenced curves here.              
                set aid_type [lindex $p_larr(aid_type) $i]
                if { $aid_type ne "" } {
                    set type_tcurve_list $time_clarr($type_t_curve_arr(${aid_type}))
                }
            }
            ns_log Notice "acc_fin::p_load_tid.1280: for ${p_larr_name} i $i time_est_short '${time_est_short}' time_est_median '${time_est_median}' time_est_long '${time_est_long}' type_tcurve_list '${type_tcurve_list}' tc_larr(x) '$tc_larr(x)' tc_larr(y) '$tc_larr(y)' tc_larr(label) '$tc_larr(label)'"
            set curve_list [acc_fin::curve_import $tc_larr(x) $tc_larr(y) $tc_larr(label) $type_tcurve_list $time_est_short $time_est_median $time_est_long $time_clarr($p1_arr(_tCurveRef)) ]
            set tcurvenum [acc_fin::larr_set time_clarr $curve_list]
            if { $tcurvenum eq "" } {
                ns_log Warning "acc_fin::p_load_tid.1284: for ${p_larr_name} i $i type $type _tCurveRef is blank for curve_list '${curve_list}'."
            } 
            
            lappend p_larr(_tCurveRef) $tcurvenum

 
            # cost curve
            set cost_dist_curve_tid ""
            set cost_dist_curve_name ""
            set cost_est_low ""
            set cost_est_median ""
            set cost_est_high ""
            if { $p2_c_dc_name_exists_p } {
                set cost_dist_curve_name [lindex $p_larr(cost_dist_curve_name) $i]
            }
            if { $cost_dist_curve_name ne "" } {
                set cost_dist_curve_tid [qss_tid_from_name $cost_dist_curve_name ]
            } 
            if { $p2_c_dc_tid_exists_p && $cost_dist_curve_tid eq "" } {
                set cost_dist_curve_tid [lindex $p_larr(cost_dist_curve_tid) $i]
            }
            # set defaults
            foreach constant $constants_list {
                set cc_larr($constant) ""
            }
            
            if { $cost_dist_curve_tid ne "" } {
                set constants_list [acc_fin::pretti_columns_list dc]
                if { ![info exists cc_cache_larr(x,${cost_dist_curve_tid}) ] } {
                    set constants_required_list [acc_fin::pretti_columns_list dc 1]
                    qss_tid_columns_to_array_of_lists ${cost_dist_curve_tid} cc_larr $constants_list $constants_required_list $instance_id $user_id
                    # add to input tid cache
                    foreach constant $constants_list {
                        set cc_cache_larr($constant,${cost_dist_curve_tid}) $cc_larr($constant)
                    }
                }
                #cc_larr(x), cc_larr(y) and optionally cc_larr(label) where _larr refers to an array where each value is a list of column data by row 1..n                
                foreach constant $constants_list {
                    set cc_larr($constant) $cc_cache_larr($constant,${cost_dist_curve_tid})
                }
            }
            if { $p2_c_est_low_exists_p } {
                set cost_est_low [lindex $p_larr(cost_est_low) $i] 
            }
            if { $p2_c_est_median_exists_p } {
                set cost_est_median [lindex $p_larr(cost_est_median) $i] 
            }
            if { $p2_c_est_high_exists_p } {
                set cost_est_high [lindex $p_larr(cost_est_high) $i]
            }

            # import curve given all the available curve choices

            if { $p2_types_exist_p && $p2_type_column_exists_p && $aid_type ne "" } {
                # aid_type exists, so include option in curve_import                
                set aid_type [lindex $p_larr(aid_type) $i]
                set type_ccurve_list $cost_clarr($type_c_curve_arr(${aid_type}))
            }
            ns_log Notice "acc_fin::p_load_tid.1352: for ${p_larr_name} i $i cost_est_low '${cost_est_low}' cost_est_median '${cost_est_median}' cost_est_high '${cost_est_high}' type_ccurve_list '${type_ccurve_list}' cc_larr(x) '$cc_larr(x)' cc_larr(y) '$cc_larr(y)' cc_larr(label) '$cc_larr(label)'"
            set curve_list [acc_fin::curve_import $cc_larr(x) $cc_larr(y) $cc_larr(label) $type_ccurve_list $cost_est_low $cost_est_median $cost_est_high $cost_clarr($p1_arr(_cCurveRef)) ]
            set ccurvenum [acc_fin::larr_set cost_clarr $curve_list]

            if { $ccurvenum eq "" } {
                ns_log Warning "acc_fin::p_load_tid.1356: for ${p_larr_name} i $i type $type _cCurveRef is blank for curve_list '${curve_list}'."
            }
            lappend p_larr(_cCurveRef) $ccurvenum
            
            # add default coefficient
            lappend p_larr(_coef) 1
        }
    } else {
        ns_log Warning "acc_fin::p_load_tid.1361: for ${p_larr_name} not processed as either p2 or p3 table."
    }
    return 1
}

ad_proc -private acc_fin::list_filter {
    type
    user_input_list
    {table_name ""}
    {list_name ""}
} {
    filters input as a list to meet basic word or reference requirements. type can be alphanum decimal natnum. If decimal or natural number (natnum) does not pass filter, value is replaced with blank. if list_name is specified and an input value doesn't pass, procedure logs an error and notifies user of count of filtered changes via pretti_log_create
} {
    set type_errors_count 0
    switch -exact $type {
        alphanumlist {
            # some table columns contain lists of items..
            set filtered_list [list ]
            foreach input_row_unfiltered $user_input_list {
                set filtered_row_list [list ]
                foreach input_unfiltered $input_row_unfiltered {
                    regsub -all -nocase -- {[^a-z0-9,]+} $input_unfiltered {} input_filtered
                    lappend filtered_row_list $input_filtered
                }
                lappend filtered_list $filtered_row_list
            }
        }

        alphanum {
            set filtered_list [list ]
            foreach input_unfiltered $user_input_list {
                regsub -all -nocase -- {[^a-z0-9,]+} $input_unfiltered {} input_filtered
                lappend filtered_list $input_filtered
            }
        }
        decimal {
            set filtered_list [list ]
            foreach input_unfiltered $user_input_list {
                if { $input_unfiltered ne "" && ![qf_is_decimal $input_unfiltered] } {
                    incr type_errors_count
                    ns_log Notice "acc_fin::list_filter.1152: val '${val}' in '${table_name}.${list_name}' is not a decimal number."
                    lappend filtered_list ""
                } else {
                    lappend filtered_list $input_unfiltered
                }
            }
        }
        natnum {
            set filtered_list [list ]
            foreach input_unfiltered $user_input_list {
                if { $input_unfiltered ne "" && ![qf_is_natural_number $input_unfiltered] } {
                    incr type_errors_count
                    ns_log Notice "acc_fin::list_filter.1164: val '${val}' in '${table_name}.${list_name}' is not a natural number."
                    lappend filtered_list ""
                } else {
                    lappend filtered_list $input_unfiltered
                }
            }
        }
    }
    if { $type_errors_count > 0 } {
        acc_fin::pretti_log_create $scenario_tid $table_name "value" "table '${table_name}' includes ${type_errors_count} bad values for '${list_name}'." $user_id $instance_id
        set type_errors_count 0
        set type_errors_p 1
    }

    return $filtered_list
}

ad_proc -public acc_fin::table_type {
    table_id
} {
    returns table flags.
} {
    set stats_list [qss_table_stats $table_id]
    # stats: name, title, comments, cell_count, row_count, template_id, flags, trashed, popularity, time last_modified, time created, user_id.
    set flags [string trim [lindex $stats_list 6]]
    return $flags
}


ad_proc -private acc_fin::curve_import {
    c_x_list
    c_y_list
    c_label_list
    curve_lists
    minimum
    median
    maximum
    default_lists
} {
    Returns curve data to standard representation for PRETTI processing. 
    Expects column labels in arbitrary order in row lists, but no titles with c_*_list.
    Distribution curve format is a spreadsheet table format with labeled columns 'x' and 'y' (and optionally 'label').
    Returns columns in order of x,y (,label) for minimizing memory footprint when used with acc_fin::larr_set.
    1. If a curve exists in c_x_list, c_y_list (, c_label_list), use it.
    2. If a curve exists in curve_lists where each element is a list of x, followed by list of y ( and perhaps followed by label), use it.
    3. If a minimum, median, and maximum is available, make a curve of it. 
    4. if an median value is available, make a curve of it, 
    5. if an ordered list of lists x,y,label exists, use it as a fallback default, otherwise 
    6. return a representation of a normalized curve as a list of lists similar to curve_lists 
} {
    # In persuit of making curve_data
    #     local curves are represented as a list of lists
    #     with each list a triplet set x, y, label, with the first row consisting of title names

    #     local 3-point (min,median,max) represented as a list of 3 elements
    #     local median represented as a single element
    #     default curve represented as a list of lists
    #     if no default available, create one based on a normalized standard.

    set c_lists [list ]

    # 1. If a curve exists in c_x_list, c_y_list (, c_label_list), use it.
    set c_x_list_len [llength $c_x_list]
    set c_y_list_len [llength $c_y_list]
    set c_label_list_len [llength $c_label_list]
    set list_len 0
    if { $c_x_list_len > 0 && $c_x_list_len < $c_y_list_len } {
        set list_len $c_x_list_len
    } elseif { $c_y_list_len > 0 } {
        set list_len $c_y_list_len
    }
    if { $list_len > 0 } {
        if { $c_label_list_len > 0 } {
            # x, y and label
            lappend c_lists [list x y label]
            ns_log Notice "acc_fin::curve_import.1237 case 1. building list from x, y and label "
            for {set i 0} {$i < $list_len} {incr i} {
                set row [list [lindex $c_x_list $i] [lindex $c_y_list $i] [lindex $c_label_list $i] ]
                lappend c_lists $row
            }
        } else {
            # x and y only
            lappend c_lists [list x y]
            ns_log Notice "acc_fin::curve_import.1244 case 1. building list from x and y "
            for {set i 0} {$i < $list_len} {incr i} {
                set row [list [lindex $c_x_list $i] [lindex $c_y_list $i] ]
                lappend c_lists $row
            }
        }
    } 

    # 2. If a curve exists in curve_lists where each element is a list of x,y(,label), use it.
    set curve_lists_len [llength $curve_lists]
    if { [llength $c_lists] == 0 && $curve_lists_len > 0 } {
        set title_list [lindex $curve_lists 0]
        set y_idx [lsearch -exact $title_list "y"]
        set x_idx [lsearch -exact $title_list "x"]
        set label_idx [lsearch -exact $title_list "label"]
        if { $label_idx > -1 } {
            set label_exists_p 1
        } else {
            set label_exists_p 0
        }
        ns_log Notice "acc_fin::curve_import.1255 case 2. building curve_lists "
        # curve exists. 
        set point_len [llength [lindex $curve_lists 0] ]
        if { $point_len > 1 } {
            # Reorder columns?
            if { $x_idx == 0 && $y_idx == 1 } {
                set c_lists $curve_lists
            } else {
                # Reorder columns for output
                foreach point_list $curve_lists {
                    set x [lindex $point_list $x_idx]
                    set y [lindex $point_list $y_idx]
                    if { $label_exists_p } {
                        set label [lindex $point_list $label_idx]
                        set point_new_list [list $x $y $label]
                    } else {
                        set point_new_list [list $x $y]
                    }
                    lappend c_lists $point_new_list
                }
            }

        }
        
    }
 
    # 3. If a minimum, median, and maximum is available, make a curve of it. 
    # or
    if { [llength $c_lists] == 0 && $minimum ne "" && $median ne "" && $maximum ne "" } {
        ns_log Notice "acc_fin::curve_import.1272 case 3. building curve from min/med/max points "
        # min,med,max values available
        # Geometric median requires all three values
        
        # time_expected = ( time_optimistic + 4 * time_most_likely + time_pessimistic ) / 6.
        # per http://en.wikipedia.org/wiki/Program_Evaluation_and_Review_Technique

        set c_lists [acc_fin::pert_omp_to_normal_dc $minimum $median $maximum ]
    }

    # 4. if an median value is available, make a curve of it, 
    #set standard_deviation 0.682689492137 
    #set std_dev_parts [expr { $standard_deviation / 4. } ]
    #set outliers [expr { 0.317310507863 / 2. } ]
    if { [llength $c_lists] == 0 && $median ne "" } {
        ns_log Notice "acc_fin::curve_import.1272 case 4. building curve from med and maybe min or max points "
        set med_label "med"
        if { $minimum eq "" } {
            set minimum $median
            set min_label $med_label
        } else {
            set min_label "min"
        }
        if { $maximum eq "" } {
            set maximum $median
            set max_label $med_label
        } else {
            set max_label "max"
        }

        # min,med,max values available
        # Geometric median requires all three values
        
        # time_expected = ( time_optimistic + 4 * time_most_likely + time_pessimistic ) / 6.
        # per http://en.wikipedia.org/wiki/Program_Evaluation_and_Review_Technique

        set c_lists [acc_fin::pert_omp_to_normal_dc $minimum $median $maximum ]
    }
    
    # 5. if an ordered list of lists x,y,label exists, use it as a fallback default
    if { [llength $c_lists] == 0 && [llength $default_lists] > 0 && [llength [lindex $default_lists 0] ] > 1 } {
        ns_log Notice "acc_fin::curve_import.1298 case 5. building curve_lists from default_lists "
        set c_lists $default_lists
    }

    # 6. return a representation of a normalized curve as a list of lists similar to curve_lists 
    if { [llength $c_lists] == 0 } {
        ns_log Notice "acc_fin::curve_import.1304 case 6. building curve_lists from blanks"
        # No time defaults.
        # following is essentially the same as acc_fin::pert_omp_to_normal_dc
        # set duration to 1 for limited block feedback.
        #set tc_larr(y) [list $outliers $std_dev_parts $std_dev_parts $std_dev_parts $std_dev_parts $outliers]
        set minimum 0.5
        set median 1.
        set maximum 2.
        set tc_larr(y) [list y $minimum $median $median $median $median $maximum]
        # using approximate cumulative distribution y values for standard deviation of 1.
        set portion [expr { 1. / 6. } ]
        set tc_larr(x) [list x $portion $portion $portion $portion $portion $portion ]
        set tc_larr(label) [list label "outlier" "standard deviation 2" "standard deviation 1" "standard deviation 1" "standard deviation 2" "outlier" ]

        set c_lists [list ]
        for {set i 0} {$i < 7} {incr i} {
            lappend c_lists [list [lindex $tc_larr(x) $i] [lindex $tc_larr(y) $i] [lindex $tc_larr(label) $i]]
        }
    }
    if { [llength $c_lists] == 0 } {
        # This shouldn't happen.. for the most part.
        ns_log Notice "acc_fin::curve_import.1312: len c_list 0 "
        ns_log Notice "acc_fin::curve_import.1312: c_x_list $c_x_list "
        ns_log Notice "acc_fin::curve_import.1312: c_y_list $c_y_list "
        ns_log Notice "acc_fin::curve_import.1312: c_label_list $c_label_list "
        ns_log Notice "acc_fin::curve_import.1312: curve_lists $curve_lists "
        ns_log Notice "acc_fin::curve_import.1312: minimum $minimum median $median maximum $maxium "
        ns_log Notice "acc_fin::curve_import.1312: default_lists $default_lists "
    }
    # Return an ordered list of lists representing a curve
        ns_log Notice "acc_fin::curve_import.1639: c_lists '$c_lists'"
    return $c_lists
}

ad_proc -public acc_fin::scenario_prettify {
    scenario_tid
    {instance_id ""}
    {user_id ""}
} {
    Processes PRETTI scenario. Returns resulting PRETTI table as a list of lists. 
} {
    # General notes:

    # Can create a projected completion curve by stepping through the range of all 
    # the performance curves N times for N point curve --instead of Monte Carlo simm.

    # About output table:
    # Vertical represents time. All tasks are rounded up to quantized time_unit.
    # Smallest task duration is the number of quantized time_units that result in 1 line of text.
    # To find smallest task duration, repeat PRETTI scenario on tracks with CP tasks by task type, 
    # then increment by quantized time_unit (row), tracking overages
    # amount to extend CP duration: 
    # collision_count / task_type * ( row_counts / ( time_quanta per task_type_duration ) + 1 )

    # Represents task bottlenecks --limits in parallel activity of same type
    # Parallel limits represented by using:
    # concurrency_limit: count of tasks of same type that can operate in parallel
    # overlap_limit: a percentage representing amount of overlap allowed.
    #                overlap_limit, in effect, creates progressions of activity

    # Since PRETTI does not schedule, don't manipulate task positioning,
    # just increase duration of task(s) to account for any overages.

    # Activities: 
    # Represent multiple dependencies of same task for example 99 cartwheels using * as in 99*cartwheels


    set setup_start [clock seconds]
    if { $instance_id eq "" } {
        set instance_id [ad_conn package_id]
    }
    if { $user_id eq "" } {
        set user_id [ad_conn user_id]
    }
    ## error_fail is set to 1 if there has been an error that prevents continued processing
    ## error_cost is set to 1 if there has been an error that prevents continued processing of costing aspects
    ## error_time is set to 1 if there has been an error that prevents continued processing of time aspects
    set error_fail 0
    set error_cost 0
    set error_time 0
    # # # load scenario values -- requires scenario_tid
    
    # activity_table contains:
    # activity_ref predecessors time_est_short time_est_median time_est_long cost_est_low cost_est_median cost_est_high time_dist_curv_eq cost_dist_curv_eq


    # # # load p1
    ns_log Notice "acc_fin::scenario_prettify.1306: scenario '$scenario_tid' start. Load p1 table"

    # get scenario into array p1_arr
    set constants_list [acc_fin::pretti_columns_list p1]
    foreach constant $constants_list {
        set p1_arr($constant) ""
    }
    # preload p1 defaults
    set p1_arr(time_probability_moment) "0.5"
    # set p1_arr(max_overlap_pct) "" defaults to 1
    # set p1_arr(max_concurrent) "" defaults to infinite ie no concurrency limit.

    # # # identify table ids to process
    set constants_required_list [acc_fin::pretti_columns_list p1 1]
    qss_tid_scalars_to_array $scenario_tid p1_arr $constants_list $constants_required_list $instance_id $user_id
    if { $p1_arr(activity_table_name) ne "" } {
        # set activity_table_tid
        set p1_arr(activity_table_tid) [qss_tid_from_name $p1_arr(activity_table_name) ]
        if { $p1_arr(activity_table_tid) eq "" } {
            acc_fin::pretti_log_create $scenario_tid "activity_table_name" "value" "activity_table_name reference does not exist." $user_id $instance_id
        }
    } 
    if { $p1_arr(task_types_name) ne "" } {
        # set task_types_tid
        set p1_arr(task_types_tid) [qss_tid_from_name $p1_arr(task_types_name) ]
        if { $p1_arr(task_types_tid) eq "" } {
            acc_fin::pretti_log_create $scenario_tid "task_types_name" "value" "task_types_name reference does not exist." $user_id $instance_id
        }
    } 
    if { $p1_arr(time_dist_curve_name) ne "" } {
        # set dist_curve_tid
        set p1_arr(time_dist_curve_tid) [qss_tid_from_name $p1_arr(time_dist_curve_name) ]
        if { $p1_arr(time_dist_curve_tid) eq "" } {
            acc_fin::pretti_log_create $scenario_tid "time_dist_curve_name" "value" "time_dist_curve_name reference does not exist." $user_id $instance_id
        }

    }
    if { $p1_arr(cost_dist_curve_name) ne "" } {
        # set dist_curve_tid
        set p1_arr(cost_dist_curve_tid) [qss_tid_from_name $p1_arr(cost_dist_curve_name) ]
        if { $p1_arr(cost_dist_curve_tid) eq "" } {
            acc_fin::pretti_log_create $scenario_tid "cost_dist_curve_name" "value" "cost_dist_curve_name reference does not exist." $user_id $instance_id
        }
    }
    
    
    set constants_exist_p 1
    set compute_message_list [list ]
    foreach constant $constants_required_list {
        if { $p1_arr($constant) eq "" } {
            set constants_exist_p 0
            lappend compute_message_list "Initial condition constant '${constant}' is required but does not exist."
            acc_fin::pretti_log_create $scenario_tid "${constant}" "value" "${constant} is required but does not exist." $user_id $instance_id
            set error_fail 1
        }
    }


    # # # set defaults specified in p1
    ns_log Notice "acc_fin::scenario_prettify.1369: scenario '$scenario_tid' set defaults specified in p1 table."


    # # # Make time_curve_data defaults
    ns_log Notice "acc_fin::scenario_prettify.1382: scenario '$scenario_tid' make time_curve_data defaults from p1."

    # These are the default values unless more specific data is specified in a task list.
    # The most specific information is used for each activity.
    # Median (most likely) point is assumed along the (cumulative) distribution curve, unless
    # a time_probability_moment is specified.  time_probability_moment is only available as a general term.
    #     local curve
    #     local 3-point (min,median,max)
    #     general curve (normalized to local 1 point median ); local 1 point median is minimum time data requirement
    #     general 3-point (normalized to local median)    
    set constants_list [acc_fin::pretti_columns_list dc]
    foreach constant $constants_list {
        set tc_larr($constant) [list ]
    }
    
    if { $p1_arr(time_dist_curve_tid) ne "" } {
        set table_stats_list [qss_table_stats $p1_arr(time_dist_curve_tid) $instance_id $user_id]
        set trashed_p [lindex $table_stats_list 7]
        if { [llength $table_stats_list] > 1 && !$trashed_p } {
            # get time curve into array tc_larr
            set constants_required_list [acc_fin::pretti_columns_list dc 1]
            qss_tid_columns_to_array_of_lists $p1_arr(time_dist_curve_tid) tc_larr $constants_list $constants_required_list $instance_id $user_id
            #tc_larr(x), tc_larr(y) and optionally tc_larr(label) where _larr refers to an array where each value is a list of column data by row 1..n
            ns_log Notice "acc_fin::scenario_prettify.1392: scenario '$scenario_tid' tc_larr(x) '$tc_larr(x)' tc_larr(y) '$tc_larr(y)'"
            # validate x and y values before importing
            set type_errors_count 0
            set type_errors_p 0
            set column_ck_list [list x y]
            foreach col $column_ck_list {
                set filtered_list [acc_fin::list_filter decimal $tc_larr($col) "time_dist_curve_tid: $p1_arr(time_dist_curve_tid)" $col]
                if { $filtered_list ne $tc_larr($col) } {
                    set type_errors_p 1
                }
            }
            if { $type_errors_p } {
                # undo data expansion
                set tc_larr(x) [list ]
                set tc_larr(y) [list ]
                if { [info exists tc_larr(label)] } {
                    set tc_larr(label) [list ]
                }
            }

        } else {
            acc_fin::pretti_log_create $scenario_tid "time_dist_curve_tid" "value" "time_dist_curve reference does not exist." $user_id $instance_id
        }
    } 
    set tc_lists [acc_fin::curve_import $tc_larr(x) $tc_larr(y) $tc_larr(label) [list ] $p1_arr(time_est_short) $p1_arr(time_est_median) $p1_arr(time_est_long) [list ] ]


    # # # Make cost_curve_data defaults
    ns_log Notice "acc_fin::scenario_prettify.1401 :scenario '$scenario_tid' make cost_curve_data defaults from p1."

    set constants_list [acc_fin::pretti_columns_list dc]
    foreach constant $constants_list {
        set cc_larr($constant) [list ]
    }
    if { $p1_arr(cost_dist_curve_tid) ne "" } {
        set table_stats_list [qss_table_stats $p1_arr(cost_dist_curve_tid) $instance_id $user_id]
        set trashed_p [lindex $table_stats_list 7]
        if { [llength $table_stats_list] > 1 && !$trashed_p } {
            set constants_required_list [acc_fin::pretti_columns_list dc 1]
            qss_tid_columns_to_array_of_lists $p1_arr(cost_dist_curve_tid) cc_larr $constants_list $constants_required_list $instance_id $user_id
            #cc_larr(x), cc_larr(y) and optionally cc_larr(label) where _larr refers to an array where each value is a list of column data by row 1..n
            ns_log Notice "acc_fin::scenario_prettify.1404: scenario '$scenario_tid' cc_larr(x) '$cc_larr(x)' cc_larr(y) '$cc_larr(y)'"
            # validate x and y values before importing
            set type_errors_count 0
            set type_errors_p 0
            set column_ck_list [list x y]
            foreach col $column_ck_list {
                set filtered_list [acc_fin::list_filter decimal $cc_larr($col) "cost_dist_curve_tid: $p1_arr(cost_dist_curve_tid)" $col]
                if { $filtered_list ne $cc_larr($col) } {
                    set type_errors_p 1
                }
            }
            if { $type_errors_p } {
                # undo data expansion
                set cc_larr(x) [list ]
                set cc_larr(y) [list ]
                if { [info exists cc_larr(label)] } {
                    set cc_larr(label) [list ]
                }
            }

        } else {
            acc_fin::pretti_log_create $scenario_tid "cost_dist_curve_tid" "value" "cost_dist_curve reference does not exist." $user_id $instance_id
        }
    }
    ns_log Notice "acc_fin::scenario_prettify.1422: scenario '$scenario_tid' cc_larr(x) '$cc_larr(x)' cc_larr(y) '$cc_larr(y)'"
    set cc_lists [acc_fin::curve_import $cc_larr(x) $cc_larr(y) $cc_larr(label) [list ] $p1_arr(cost_est_low) $p1_arr(cost_est_median) $p1_arr(cost_est_high) [list ] ]
    
    # curves_larr ie *_c_larr has 2 versions: time as t_c_larr and cost as c_c_larr
    # index 0 is default
    set p1_arr(_tCurveRef) [acc_fin::larr_set time_clarr $tc_lists]
 #   set time_clarr(0) $tc_lists
    set p1_arr(_cCurveRef) [acc_fin::larr_set cost_clarr $cc_lists]
#    set cost_clarr(0) $cc_lists
    ns_log Notice "acc_fin::scenario_prettify.1426: scenario '$scenario_tid' default t curve: time_clarr($p1_arr(_tCurveRef)) '$tc_lists'"
    ns_log Notice "acc_fin::scenario_prettify.1427: scenario '$scenario_tid' default c curve: cost_clarr($p1_arr(_cCurveRef)) '$cc_lists'"
    
    # # # import task_types table p3
    ns_log Notice "acc_fin::scenario_prettify.1432: scenario '$scenario_tid' import task_types table p3, if any."


    #### Use [lsearch -regexp {[a-z][0-9]+} -all -inline $x_list] to screen alt debit/credit/"cost/revenue" columns and create list for custom summary feature.
    #### Use [lsearch -regexp {[a-z][0-9]+s} -all -inline $x_list] to screen alt time columns and create list for a scheduling feature
    #### with parameters defined in scenario or as a separate compilation of pretti output
    
    # set defaults
    set constants_list [acc_fin::pretti_columns_list p3]
    foreach constant $constants_list {
        set p3_larr($constant) [list ]
    }
    if { $p1_arr(task_types_tid) ne "" } {
        set table_stats_list [qss_table_stats $p1_arr(task_types_tid) $instance_id $user_id]
        set trashed_p [lindex $table_stats_list 7]
        if { [llength $table_stats_list] > 1 && !$trashed_p } {
            set constants_required_list [acc_fin::pretti_columns_list p3 1]
            ns_log Notice "acc_fin::scenario_prettify.1459: scenario '$scenario_tid' import task_types from '$p1_arr(task_types_tid)'."
            acc_fin::p_load_tid $constants_list $constants_required_list p3_larr $p1_arr(task_types_tid) "" $instance_id $user_id
            ns_log Notice "acc_fin::scenario_prettify.1460: scenario '$scenario_tid' p3_larr '[array get p3_larr]'"

            # validate decimal values before importing
            set type_errors_count 0
            set type_errors_p 0
            set column_maybe_ck_list [list max_concurrent max_overlap_pct time_dist_curve_tid cost_dist_curve_tid time_est_short time_est_median time_est_long cost_est_low cost_est_median cost_est_high]
            set column_ck_list [list ]
            set titles_list [array names p3_larr]
            # collect titles that are in p3_larr that should be checked
            foreach col $column_maybe_ck_list {
                if { [lsearch -exact $titles_list $col] > -1 } {
                    lappend column_ck_list $col
                }
            }
            # check data for each column
            foreach col $column_ck_list {
                if { [string range $col end-3 end] eq "_tid" } {
                    set filtered_list [acc_fin::list_filter natnum $p3_larr($col) p3 $col]
                } else {
                    set filtered_list [acc_fin::list_filter decimal $p3_larr($col) p3 $col]
                }
                if { $filtered_list ne $p3_larr($col) } {
                    set type_errors_p 1
                }
            }
            if { [info exists p1_arr(index_equation) ] } {
                # validate equation or set empty
                set index_eq ""
                # only allow + - / * $, logical comparisions > < == != and numbers.  $number converts to one of the available row numbers that returns a number from in p4 
                regsub -nocase -all -- {[^\$\/\+\-\*\(\)\.\<\>\=\!\ 0-9]+} $p1_arr(index_equation) "" index_eq
                # add extra spaces to help expr avoid misinterpretations, but can't assume that for negative numbers vs. minus sign
                regsub -nocase -all -- {([\/\+\*\(\)])} $index_eq " \1 " index_eq
                # get rid of extra spaces
                regsub -nocase -all -- {[ ]+} $index_eq " " index_eq
                set vars_list [list ]
                foreach {var0 var1 scratch} [acc_fin::pretti_equation_vars ] {
                    set var2 " $"
                    append var2 $var0
                    set var3 " \[qaf_fp ${"
                    append var3 $var1
                    append var3 "} \] "
                    regsub -nocase -all -- $var2 $index_eq $var3 index_eq
                }
                # unqoute the brackets
                regsub -nocase -all -- {[\\]} $index_eq {} index_eq

            }
            if { $type_errors_p } {
                # undo data expansion
                foreach title $titles_list {
                set p3_larr($title) [list ]
                }
            }

        } else {
            acc_fin::pretti_log_create $scenario_tid "task_types_tid" "value" "task_types_tid reference does not exist." $user_id $instance_id
        }
    }
    # The multi-layered aspect of curve data storage needs a double-pointer to be efficient for projects with large memory footprints
    # act_curve_arr($act) => curve_ref
    # type_t_curve_arr($type) => curve_ref
    # type_c_curve_arr($type) => curve_ref
    # tid_curve_arr($tid) => curve_ref
    # where curve_ref is index of curves_lol
    # where curve_ref = 0 is default
    # so, add a p2_larr(_cCurveRef) and p2_larr(_tCurveRef) column which references curves_lol
    #  similarly, add a p3_larr(_cCurveRef) and p3_larr(_tCurveRef) column
        
    # # # import activity table p2
    ns_log Notice "acc_fin::scenario_prettify.1465: scenario '$scenario_tid' import activity table p2 (required)."


    #### Use lsearch -glob or -regexp to screen alt columns and create list for custom summary feature. [a-z][0-9]
    #### ..connected to cost_probability_moment.. so columns represent curve IDs..
    #### Use [lsearch -regexp {[a-z][0-9]s} -all -inline $x_list] to screen alt time columns and create list for a scheduling feature.

    # set defaults
    set constants_list [acc_fin::pretti_columns_list p2]
    foreach constant $constants_list {
        set p2_larr($constant) [list ]
    }
    if { $p1_arr(activity_table_tid) ne "" } {
        set table_stats_list [qss_table_stats $p1_arr(activity_table_tid) $instance_id $user_id]
        set trashed_p [lindex $table_stats_list 7]
#        ns_log Notice "acc_fin::scenario_prettify.1443: llength table_stats_list [llength $table_stats_list] '$table_stats_list'"
        if { [llength $table_stats_list] > 1 && !$trashed_p} {
            # load activity table
            set constants_required_list [acc_fin::pretti_columns_list p2 1]
            ns_log Notice "acc_fin::scenario_prettify.1495: scenario '$scenario_tid' import activity_table_tid from '$p1_arr(activity_table_tid)'."
            acc_fin::p_load_tid $constants_list $constants_required_list p2_larr $p1_arr(activity_table_tid) p3_larr $instance_id $user_id
            # filter user input
            set p2_larr(activity_ref) [acc_fin::list_filter alphanum $p2_larr(activity_ref) "p2" "activity_ref"]
            set p2_larr(dependent_tasks) [acc_fin::list_filter alphanumlist $p2_larr(dependent_tasks) "p2" "dependent_tasks"]
            
        } else {
            acc_fin::pretti_log_create $scenario_tid "activity_table_tid" "value" "activity_table_tid reference does not exist, but is required.(ref1450)" $user_id $instance_id
        }
    } else {
            acc_fin::pretti_log_create $scenario_tid "activity_table_tid" "value" "activity_table_tid reference does not exist, but is required.(ref1453)" $user_id $instance_id
    }
    
    # Substitute task_type data (p3_larr) into activity data (p2_larr) when p2_larr data is less detailed or missing.
    # Curve data has already been substituted in p_load_tid
    # Other substitutions when a p2_larr field is blank.

    # Effectively, p2 imports parts of p3 that are more detailed than p2, to build the final p2 activity table
    # p3 includes default modifiers from p1 as well.

    set constants_woc_list [list name description]
    # _woc_ = without curve data (or columns)
    # Removed dependent_tasks from task_type substitution, 
    # because dependent_tasks creates a level of complexity significant enough to be avoided
    # through program set-up at this time.
    set p3_type_list $p3_larr(type)
    set p2_task_type_list $p2_larr(aid_type)
    ## activities_list  list of activities to process
    set activities_list $p2_larr(activity_ref)

    foreach constant $constants_woc_list {
        if { [llength $p2_larr(aid_type) ] > 0 && [llength $p3_larr($constant)] > 0 } {
            set i 0
            set p2_col_list $p2_larr($constant)
            foreach act $activities_list {
                set p2_value [lindex $p2_col_list $i]
                if { $p2_value eq "" } {
                    set ii [lsearch -exact $p3_type_list [lindex $p2_task_type_list $i]]
                    set p2_col_list [lreplace $p2_col_list $i $i [lindex $p3_larr($constant) $ii] ]
                }
                incr i
            }
            set p2_larr($constant) $p2_col_list
        }
    }
    
    # # # Confirm that dependent activities exist as activities.
    ns_log Notice "acc_fin::scenario_prettify.1527: scenario '$scenario_tid' Confirm p2 dependents exist as activities, expand dependents with coefficients."

    #  Expand p2_larr to include dependent activities with coefficients.
    #  by appending new definitions of tasks that don't yet have defined coefficients.


    ns_log Notice "acc_fin::scenario_prettify.1529: scenario '$scenario_tid' activities_list '${activities_list}'"     
    ns_log Notice "acc_fin::scenario_prettify.1531: scenario '$scenario_tid' p2_larr(dependent_tasks) '$p2_larr(dependent_tasks)'"   
    foreach dependencies_list $p2_larr(dependent_tasks) {
        ns_log Notice "acc_fin::scenario_prettify.1533: scenario '$scenario_tid' dependencies_list '${dependencies_list}'"     
        foreach activity $dependencies_list {
            ns_log Notice "acc_fin::scenario_prettify.1535: scenario '$scenario_tid' activity '${activity}'"     
            if { [lsearch -exact $activities_list $activity] == -1 } {
                # A dependent activity doesn't exist..
                ns_log Notice "acc_fin::scenario_prettify.1619: scenario '$scenario_tid' activity '$activity' doesn't exist on direct search."
                set term ""
                set coefficient ""
                # Is $activity an existing activity, but referenced with a coeffient?
                set scratch ""

                if { [regexp -- {^([0-9]+)[\*]([^\*]+)} $activity scratch coefficient term] } {
                    ns_log Notice "acc_fin::scenario_prettify.1624: scenario '$scenario_tid' activity '$activity' is part coefficient '$coefficient' and part term '$term'"
                    # If $term is a defined activity, get index
                    set term_idx [lsearch -exact $activities_list $term]
                    if { $term_idx > -1 } {
                        # Requirements met: There is a coefficient and an existing activity.
                        ns_log Notice "acc_fin::scenario_prettify.1632: scenario '$scenario_tid' term '$term' exists as an activity, so creating new activity with coefficient."
                        # Generate a new activity with coeffient for this run.
                        foreach constant $constants_list {
                            lappend p2_larr($constant) [lindex $p2_larr($constant) $term_idx]
                        }
                        lappend p2_larr(_coef) $coefficient
                        # create new tCurves and cCurves and references to them.
                        set tcurvenum [lindex $p2_larr(_tCurveRef) $term_idx]
                        if { $tcurvenum ne "" } {
                            # create new curve based on the one referenced 
                            # parameters: max_concurrent max_overlap_pct021
                            #      max_overlap_pct  (as a percentage from 0 to 1, blank = 1)
                            #      max_concurrent       (as an integer, blank = no limit)
                            # activity curve @tcurvenum
                            # for each point t(pm) in curve time_clarr($_tCurveRef), max_overlap_pct, max_concurrent, coeffient c
                            if { [ad_var_type_check_number_p $max_overlap_pct ] && $max_overlap_pct < 2 && $max_overlap_pct > -1 } {
                                # validated
                            } else {
                                acc_fin::pretti_log_create $scenario_tid "max_overlap_pct" "value" "max_overlap_pct '$max_overlap_pct' is out of range. Set to 1 (100%). (ref1520)" $user_id $instance_id
                                set max_overlap_pct 1.
                            }
                            # coef_p1 * max_concurrent + coef_p2 = $coefficient
                            set coef_p1 [expr { int( $coeffcient / $max_concurrent ) } ]
                            set coef_p2 [expr { $coefficient - $coef_p1 * $max_concurrent } ]
                            # coef_p2 should be at most 1 less than max_concurrent
                            # max_trailing_pct = 1. - max_overlap_pct
                            # k3 calculates length of a full block max_concurrent wide
                            set k3 [expr { 1. + ( $coef_p1 - 1 ) * ( 1. - $max_overlap_pct ) } ]
                            # k4 calculates length of partial blocks (one more activity than full block activity count, but maybe not overlapped as far)
                            set k4 [expr { 1. + ( $coef_p2 - 1 ) * ( 1. - $max_overlap_pct ) } ]
                            # Choose the longer of the two blocks:
                            set k5 [f::max $k3 $k4]
                            set curve_lol [list ]
                            foreach point $time_clarr($tcurvenum) {
                                # point: x y label
                                set x [lindex $point 0]
                                set y [lindex $point 1]
                                set label [lindex $point 2]
                                set y_new [expr { $y * $k5 } ]
                                set point_new [list $y_new $x $label]
                                lappend curve_lol $point_new
                            }
                            # save new curve

                            set tcurvenum [acc_fin::larr_set time_clarr $curve_lol]
                            # save new reference
                            lappend $p2_larr(_tCurveRef) $tcurvenum
                            ns_log Notice "acc_fin::scenario_prettify.1674: scenario '$scenario_tid' new t curve: time_clarr($tcurvenum) '$curve_lol'"
                        } else {
                            lappend $p2_larr(_tCurveRef) ""
                            ns_log Warning "acc_fin::scenario_prettify.1676: scenario '$scenario_tid' NO tcurvenum for '$curve_lol'"
                        }
                        if { [lindex $p2_larr(_cCurveRef) $term_idx] ne "" } {
                            # New curve is isn't affected by overlap or max_concurrent. 
                            # New curve is simple multiplication of old and coefficient
                            # create new curve
                            set curve_lol [list ]
                            foreach point $cost_clarr($ccurvenum) {
                                # point: y x label
                                set x [lindex $point 0]
                                set y [lindex $point 1]
                                set label [lindex $point 2]
                                set y_new [expr { $y * $coefficient } ]
                                set point_new [list $y_new $x $label]
                                lappend curve_lol $point_new
                            }
                            
                            # save new curve
                            set ccurvenum [acc_fin::larr_set cost_clarr $curve_lol]
                            # save new reference
                            lappend $p2_larr(_cCurveRef) $ccurvenum
                            ns_log Notice "acc_fin::scenario_prettify.1694: scenario '$scenario_tid' new c curve: cost_clarr($ccurvenum) '$curve_lol'"
                        } else {
                            lappend $p2_larr(_cCurveRef) ""
                        }
                        ns_log Notice "acc_fin::scenario_prettify.1700: scenario '$scenario_tid' term '$term' tcurvenum '$tcurvenum' ccurvenum '$ccurvenum'"
                    } else {
                        # No activity defined for this factor (term with coefficient), flag an error --missing dependency.
                        lappend compute_message_list "Dependency '${term}' is undefined, referenced in: '${activity}'."
                        acc_fin::pretti_log_create $scenario_tid "${term}" "value" "Dependency '${term}' referenced in '${activity}' is undefined.(ref1576)" $user_id $instance_id
                        set error_fail 1
                    }
                } else {
                    # No activity defined for this factor (term with coefficient), flag an error --missing dependency.
                    lappend compute_message_list "Dependency '${activity}' is an undefined activity."
                    acc_fin::pretti_log_create $scenario_tid "${activity}" "value" "Dependency '${activity}' is an undefined activity. (ref1582)" $user_id $instance_id
                    set error_fail 1
                }
            }
            # else, an activity for the dependency exists. Do nothing.
        }
    }
    if { !$error_fail } {
        # # # Multiple probability_moments allowed
        set t_moment_list [split $p1_arr(time_probability_moment)]
        if { $p1_arr(cost_probability_moment) ne "" } {
            set c_moment_list [split $p1_arr(cost_probability_moment)]
            set c_moment_blank_p 0
            ns_log Notice "acc_fin::scenario_prettify.1733: scenario '$scenario_tid' prepare p1 time '${t_moment_list}'and cost '${c_moment_list}' probability_moment loops."
        } else {
            set c_moment_blank_p 1
        }
        ns_log Notice "acc_fin::scenario_prettify.1750: scenario '$scenario_tid' prepare p1 time '${t_moment_list}'and c_moment_blank_p ${c_moment_blank_p}."


        # Be sure any new values are nullified between each loop
        set setup_end [clock seconds]
        set time_start [clock seconds]
        foreach t_moment $t_moment_list {
            
            # Calculate base durations for time_probability_moment. These work for activities and task types.
            array unset t_est_arr
            foreach tCurve [array names time_clarr] {
                set t_est_arr($tCurve) [qaf_y_of_x_dist_curve $t_moment $time_clarr($tCurve) ]
                ns_log Notice "acc_fin::scenario_prettify.1756: scenario '$scenario_tid' tCurve '$tCurve' t_est_arr($tCurve) '$t_est_arr($tCurve)' ."
            }
            if { $c_moment_blank_p } {
                # if cost_probability_moment is blank, loop 1:1 using time_probability_moment values
                set c_moment_list [list $t_moment]
            }
            foreach c_moment $c_moment_list {
                # Calculate base costs for cost_probability_moment. These work for activities and task types.
                array unset c_est_arr
                foreach cCurve [array names cost_clarr] {
                    set c_est_arr($cCurve) [qaf_y_of_x_dist_curve $c_moment $cost_clarr($cCurve) ]
                }
                # Create activity time estimate and cost estimate arrays for repeated use in main loop
                # These arrays vary in values by t_moment and c_moment
                set i 0
                array unset act_time_expected_arr
                array unset trunk_duration_arr
                array unset act_cost_expected_arr
                array unset path_cost_arr
                array unset depnc_eq_arr
                
                foreach act $activities_list {
                    # first paths are single activities, so following line of code doesn't seem significant.
                    # It's just here so that internal representation is consistent.
                    set act_list [list $act]
                    # the first paths are single activities, subsequently time expected and duration are same values
                    set tref [lindex $p2_larr(_tCurveRef) $i]
                    if { $tref ne "" } {
                        set time_expected $t_est_arr($tref)
                        ## act_time_expected_arr(act) is the time expected to complete an activity
                        set act_time_expected_arr($act) $time_expected
                        ## trunk_duration_arr(act_tree_list) is the time expected to complete an activity and its dependents
                        set trunk_duration_arr(${act_list}) $time_expected
                    } else {
                        ns_log Warning "acc_fin::scenario_prettify.1763: scenario '$scenario_tid' act '$act' tref '${tref}' p2_larr(_tCurveRef) '$p2_larr(_tCurveRef)'"
                        acc_fin::pretti_log_create $scenario_tid "${act}" "value" "Duration referenced in activity  '${act}' is undefined.(ref1763)" $user_id $instance_id
                        set error_time 1
                    }
                    # the first paths are single activities, subsequently cost expected and path segment costs are same values
                    set cref [lindex $p2_larr(_cCurveRef) $i]
                    if { $cref ne "" } {
                        set cost_expected $c_est_arr($cref)
                        ## act_cost_expected_arr(act) is the cost expected to complete an activity
                        set act_cost_expected_arr($act) $cost_expected
                        ## path_cost_arr(act_tree_list) is the cost expected to complete an activity and its dependents
                        set path_cost_arr(${act_list}) $cost_expected
                    } else {
                        ns_log Warning "acc_fin::scenario_prettify.1773: scenario '$scenario_tid' act '$act' cref '${cref}' p2_larr(_cCurveRef) '$p2_larr(_cCurveRef)'"
                        acc_fin::pretti_log_create $scenario_tid "${act}" "value" "Cost referenced in activity '${act}' is undefined.(ref1773)" $user_id $instance_id
                        set error_cost 1
                    }
                    incr i
                }
                if { $error_cost && $error_time } {
                    set error_fail 1
                    return $error_fail
                }
                
                # handy api ref
                # util_commify_number
                # format "% 8.2f" $num
                
                # PERTTI calculations
                
                # Build activity dependent map
                ns_log Notice "acc_fin::scenario_prettify.1783: scenario '$scenario_tid' build activity dependents map and sequences for t_moment '${t_moment}' c_moment '${c_moment}'"
                #  activity map table:  depnc_larr($activity_ref) dependent_tasks_list
                #  array of activity_ref sequence_num: act_seq_num_arr($activity_ref) sequence_number
                
                # An activity_ref's sequence is one more than the max sequence_num of its dependencies
                set i 0
                set sequence_1 0
                array unset act_seq_num_arr
                array unset dependencies_larr
                array unset act_calculated_p_larr

                foreach act $activities_list {
                    #   depnc: comma list of activity's dependencies
                    set depnc [lindex $p2_larr(dependent_tasks) $i]
                    ## t_dc_source_arr(act) answers Q: what is source of time distribution curve?
                    set t_dc_source_arr($act) [lindex $p2_larr(_tDcSource) $i ]
                    ## c_dc_source_arr(act) answers Q: what is source of cost distribution curve?
                    set c_dc_source_arr($act) [lindex $p2_larr(_cDcSource) $i ]

                    # Filter out any blanks
                    set scratch_list [split $depnc ";, "]
                    set scratch2_list [list ]
                    foreach dep $scratch_list {
                        if { $dep ne "" } {
                            lappend scratch2_list $dep
                        }
                    }
                    ##   dependencies_larr() is a list of direct dependencies for each activity
                    set dependencies_larr($act) $scratch2_list
                    set act_calculated_p_larr($act) 0
                    ns_log Notice "acc_finn::scenario_prettify.1793: scenario '$scenario_tid' set act_calculated_p_larr($act) 0 len \$act [string length $act]"
                    ##   act_seq_num_arr is relative sequence number of an activity in it's path. 
                    set act_seq_num_arr($act) $sequence_1
                    ## act_coef(act) is the coefficient of an activity. If activity is defined as a multiple of another activity, it is an integer greater than 1 otherwise 1.
                    set act_coef($act) [lindex $p2_larr(_coef) $i]
                    incr i
                }
                
                # Calculate paths in the main loop to save resources.
                #  Each path is a list of numbers referenced by array, where 
                #  array indexes last path activity (of a dependency track).
                #  set path_segment_ends_in_lists($act) 
                #  so future segments can quickly reference it to build theirs.
                
                # a ptrack (partial track) is an incomplete path

                # This keeps path making nearly linear. There are up to as many path tree references as there are activities..
                
                # Since some activities depend on others, some of the references are ptracks.
                
                # All paths must be assessed in order to handle all possibilities
                # Paths are used to determine critical path and fast crawl a single path.
                
                # An activity cannot start until the longest dependent segment (branch) has completed.
                
                # For strict critical path, create a list of lists, where 
                # each list is a list of activity and dependencies from start to finish (aka path). 
                # The longest duration path is the strict defintion of critical path.
                
                # create dependency check equations
                ns_log Notice "acc_fin::scenario_prettify.1737: scenario '$scenario_tid' create equations for checking if dependencies are met."
                
                # # # main process looping
                ns_log Notice "acc_fin::scenario_prettify.2284: scenario '$scenario_tid' begin main process"
                
                
                array unset act_seq_list_arr
                array unset act_count_of_seq_arr
                array unset trunk_duration_arr
                array unset trunk_cost_arr
                array unset subtrees_larr
                array unset path_tree_p_arr
                set all_paths_calculated_p 0
                ## activity_count is length activities_list
                set activity_count [llength $activities_list]
                set i 0
                set act_seq_list_arr(${sequence_1}) [list ]
                ##   act_count_of_seq_arr( sequence_number) is the count of activities at this sequence number across all paths, 0 is first sequence number
                set act_count_of_seq_arr(${sequence_1}) 0
                set tree_seg_dur_lists [list ]

                
                while { !$all_paths_calculated_p && $activity_count > $i } {
                    set all_paths_calculated_p 1
                    foreach act $activities_list {

                        set dependencies_met_p 1
                        foreach dep $dependencies_larr($act) {
                            ns_log Notice "acc_fin::scenario_prettify.2308: dep $dep act_calculated_p_larr($dep) '$act_calculated_p_larr($dep)' len \$dep [string length $dep]"
                            set dependencies_met_p [expr { $dependencies_met_p && $act_calculated_p_larr($dep) } ]
                        }
                        ##   act_seq_max is the maximum path length in context of sequence_number
                        set act_seq_max $sequence_1

                        ns_log Notice "acc_fin::scenario_prettify.2314: scenario '$scenario_tid' act $act act_seq_max ${act_seq_max}"
                        if { $dependencies_met_p } {
                            # Calc max_num: maximum relative sequence number for activity dependencies
                            set max_num 0
                            foreach test_act $dependencies_larr($act) {
                                set test $act_seq_num_arr(${test_act})
                                if { $max_num < $test } {
                                    set max_num $test
                                }
                            }
                            
                            # Add activity's relative sequence number: act_seq_num_arr
                            set act_seq_nbr [expr { $max_num + 1 } ]
                            set act_seq_num_arr($act) $act_seq_nbr

                            set act_calculated_p_larr($act) 1
                            # increment act_seq_max and set defaults for a new max seq number?
                            if { $act_seq_nbr > $act_seq_max } {
                                set act_seq_max $act_seq_nbr
                                set act_seq_list_arr(${act_seq_max}) [list ]
                                set act_count_of_seq_arr(${act_seq_max}) 0
                            }
                            # add activity to the network for this sequence number
                            lappend act_seq_list_arr(${act_seq_nbr}) $act
                            incr act_count_of_seq_arr(${act_seq_nbr})


                            # Analyze prior path segments and branches
                            
                            if { !$error_time } {
                                # branches_duration_max is the min. path duration to complete dependent paths
                                # set branches_duration_max to the longest duration of dependent segments.
                                set branches_duration_max 0.
                                foreach dep_act $dependencies_larr($act) {
                                    if { $trunk_duration_arr(${dep_act}) > $branches_duration_max } {
                                        set branches_duration_max $trunk_duration_arr(${dep_act})
                                    }
                                }
                                ##   trunk_duration_arr(act) is duration of ptrack up to (and including) activity.
                                set trunk_duration_arr($act) [expr { $branches_duration_max + $act_time_expected_arr($act) } ]
                            }

                            if { !$error_cost } {
                                set paths_cost_sum 0.
                                foreach dep_act $dependencies_larr($act) {
                                    #   paths_cost_sum is sum of costs for each dependent ptrack
                                    set paths_cost_sum [expr { $paths_cost_sum + $act_cost_expected_arr(${dep_act}) } ]
                                }
                                ##   trunk_cost_arr is cost of all dependent ptrack plus cost of activity
                                set trunk_cost_arr($act) [expr { $paths_cost_sum + $act_cost_expected_arr($act) } ]
                            }

                            # subtrees_larr(activity) is an array of list of ptracks ending with trunk activity
                            #   paths (or ptracks) represented as a list of activity lists in chronological order (last acitivty last).
                            #   For example, if A depends on B and C, and C depends on D, and A depends on F then:
                            #   subtrees_larr(A) == (list (list B A) (list D C A ) (list F A) )
                            set subtrees_larr($act) [list ]
                            set dependents_count_arr($act) 0
                            foreach dep_act $dependencies_larr($act) {
                                foreach path_list $subtrees_larr(${dep_act}) {
                                    # Mark which tracks are complete (not partial track segments), 
                                    # so that total program cost calculations don't include duplicate, incomplete ptracks
                                    ## path_tree_p_arr answers question: is this tree of ptracks complete (ie not a subset of another track or tree)?
                                    set path_tree_p_arr($dep_act) 0
                                    set path_tree_p_arr($act) 1
                                    set path_new_list $path_list
                                    lappend path_new_list $act
                                    lappend subtrees_larr($act) $path_new_list
                                }
                                ## dependents_count_arr(act) is count number of activities in each subtree, not including the activity itself.
                                set dependents_count_arr($act) [expr { $dependents_count_arr($act) + $dependents_count_arr($dep_act) + 1 } ]
                            }
                            if { [llength $subtrees_larr($act)] eq 0 } {
                                lappend subtrees_larr($act) $act
                                set path_tree_p_arr($act) 1
                            }
                        }

                        set dependencies_met_p 1
                        foreach dep $dependencies_larr($act) {
                            ns_log Notice "acc_fin::scenario_prettify.2392: dep $dep act_calculated_p_larr($dep) '$act_calculated_p_larr($dep)' len \$dep [string length $dep]"
                            set dependencies_met_p [expr { $dependencies_met_p && $act_calculated_p_larr($dep) } ]
                        }
                        set all_paths_calculated_p [expr { $all_paths_calculated_p && $dependencies_met_p } ]
                    }
                    incr i
                }
                
                
                # # # Curve calculations complete for t_moment and c_moment.
                ns_log Notice "acc_fin::scenario_prettify.2402: scenario '$scenario_tid' Curve calculations completed for t_moment and c_moment. "
                
                
                set all_deps_met_p 1
                foreach act $activities_list {
                    set dependencies_met_p 1
                    foreach dep $dependencies_larr($act) {
                        ns_log Notice "acc_fin::scenario_prettify.2409: dep $dep act_calculated_p_larr($dep) '$act_calculated_p_larr($dep)' len \$dep [string length $dep]"
                        set dependencies_met_p [expr { $dependencies_met_p && $act_calculated_p_larr($dep) } ]
                    }
                    set all_deps_met_p [expr { $dependencies_met_p && $all_deps_met_p } ] 
                    # ns_log Notice "acc_fin::scenario_prettify: act $act act_seq_num_arr '$act_seq_num_arr($act)'"
                    # ns_log Notice "acc_fin::scenario_prettify: act_seq_list_arr '$act_seq_list_arr($act_seq_num_arr($act))' $act_count_of_seq_arr($act_seq_num_arr($act))"
                }
                ns_log Notice "acc_fin::scenario_prettify.2416: scenario '$scenario_tid' All dependencies met? 1 = yes. all_deps_met_p $all_deps_met_p"
                
            
                # # # compile results for report
                ns_log Notice "acc_fin::scenario_prettify.2431: scenario '$scenario_tid' compile results for report."


                #   paths_lists is a list of (full paths, subtotal duration, subtotal cost)
                set paths_lists [list ]
                set paths_idx 0
                foreach act $activities_list {
                    # Remove partial tracks from subtrees by placing only paths in paths_lists
                    if { $path_tree_p_arr($act) } {
                        # subtrees_larr($act) is a tree of full paths here.
                        # Expand path trees to a list of paths
                        foreach path_list $subtrees_larr($act) {
                            # build a sortable list
                            set row_list [list ]

                            # paths_lists 0
                            lappend row_list $paths_idx

                            set paths_arr(${path_idx}) $path_list
                           
                            if { !$error_time } {
                                # calculate no-float, no-lag duration for each path
                                set path_duration  0.
                                set ptrack_list [list ]
                                foreach pa $path_list {
                                    lappend ptrack_list $pa
                                    # subtotal
                                    set path_duration [expr { $path_duration + $act_time_expected_arr($pa) } ]
                                    set ptrack_dur_arr($ptrack_list) $path_duration
                                }
                                # save this for later reporting
                                # set path_dur_arr($path_list) $path_duration
                                # duplicative. ptrack_dur_arr($ptrack_list) = path_dur_arr($path_list) here
                            } else {
                                set path_duration ""
                            }
                            # paths_lists 1
                            lappend row_list $path_duration

                            if { !$error_cost } {
                                # calculate cost for each path. 
                                set path_cost 0.
                                set ptrack_list [list ]
                                # Since paths share activities, some costs are duplicative and so do not total these between paths
                                foreach pa $path_list {
                                    lappend ptrack_list $pa
                                    # subtotal
                                    set path_cost [expr { $path_cost + $act_cost_expected_arr($pa) } ]
                                    set path_cost_arr($ptrack_list) $path_cost
                                }
                                # save this for later reporting
                                #set path_cost_arr($path_list) $path_cost
                                # duplicative. see above.
                            } else {
                                set path_cost ""
                            }
                            # paths_lists 2
                            lappend row_list $path_cost

                            # if duration and cost are unavailable, list will be sorted by longest path..
                            # paths_lists 3
                            set path_len [llength $path_list ]
                            ## path_len_arr(path_idx) is length of path list
                            set path_len_arr(${path_idx}) $path_len
                            lappend row_list $path_len

                            set path_len_w_coef 0
                            foreach pa $path_list {
                                incr path_len_w_coef $act_coef($pa)
                            }
                            # paths_lists 4
                            ## path_len_w_coef_arr is total number of activities in a path (with coefficients)
                            set path_len_w_coef_arr(${path_idx})
                            lappend row_list $path_len_w_coef

                            # calculate custom equation for custom CP?
                            ## index_custom is value of custom index equation index_eq, or empty string
                            set index_custom ""
                            if { !$error_fail && $index_eq ne "" } {
                                if { [catch {
                                    set index_custom [expr { $index_eq } ]
                                } _error_text]} {
                                    set error_fail 1
                                    ns_log Warning "acc_fin::scenario_prettify.2646: scenario '$scenario_tid' act '$act' index_eq '${index_eq}'"
                                    acc_fin::pretti_log_create $scenario_tid "${act}" "calculation" "There was an error in calculation '${index_eq}' of custom equation for PRETTI index (ref2646). Error text is '${_error_text}'" $user_id $instance_id
                                }
                            }
                            # paths_lists 5
                            lappend row_list $index_custom

                            lappend paths_lists $row_list
                            incr paths_idx
                        }
                    }
                }
                ## paths_count_max is the number of paths ie length of paths_list
                set paths_count_max [expr { $paths_idx - 1 } ]
                # paths_list: (list path_list duration cost length)
                if { !$error_fail && $index_eq ne "" } {
                    # sort by custom created index
                    set paths_sort1_lists [lsort -decreasing -real -index 5 $paths_lists]

                } elseif { !$error_time } {

                    # sort by path duration
                    # critical path is the longest path. Float is the difference between CP and next longest CP.
                    # create an array of paths from longest to shortest duration to help build base table
                    set paths_sort1_lists [lsort -decreasing -real -index 1 $paths_lists]
                             

                } elseif { !$error_cost } {

                    # make something useful for cost biased table, critical_path is most costly.. etc.
                    # sort by path cost
                    # critical path is the longest path. Float is the difference between CP and next longest CP.
                    # create an array of paths from longest to shortest duration to help build base table
                    set paths_sort1_lists [lsort -decreasing -real -index 2 $paths_lists]
                    
                } else {

                    # make something that doesn't break the final table build. critical_path is largest count of activities..
                    # sort by number of activities per path
                    # critical path is the longest path. 
                    # create an array of paths from longest to shortest number of activities
                    set paths_sort1_lists [lsort -decreasing -integer -index 4 $paths_lists]
                    
                }

                # Extract most significant CP alternates for a focused table
                # by counting the number of times an act is used in the largest proportion (first half) of paths in path_set_dur_sort1_list
                
                # act_freq_in_load_cp_alts_arr counts number of times an activity appears in all paths
                # determine act_freq_in_load_cp_alts_arr(activity)
                # Initialize
                foreach act $activities_list {
                    set act_freq_in_load_cp_alts_arr($act) 0
                }
                foreach path_list $paths_lists {
                    foreach act $path_list {
                        incr act_freq_in_load_cp_alts_arr($act) act_coef($act)
                    }
                }
                
                # Make a list of activities sorted by popularity (appearing in the most paths)
                set act_count_list [list ]
                foreach act $activities_list {
                    lappend act_count_list [list $act $act_freq_in_load_cp_alts_arr($act)]
                }
                set activities_sorted_list [lsort -decreasing -integer -index 1 $act_count_list]
                set act_ath_count_median_pos [expr { int( $paths_count_max / 2. } + 1. ) ]
                set act_count_max [lindex [lindex $activities_sorted_list 0] 1]
                set act_count_median [lindex [lindex $activities_sorted_list $act_count_median_pos] 1]

                # Critical Path (CP) is: 
                set paths_cp_idx [lindex $paths_sort1_lists 0]
                set cp_row_list $paths_arr($paths_cp_idx)
                set cp_list [lindex $cp_row_list 0]
                set cp_duration [lindex $cp_row_list 1]
                set cp_cost [lindex $cp_row_list 2]
                set cp_len [lindex $cp_row_list 3]
#### reviewed to here. except curve_import needs to insert the feedback on how cost and duration curves are chosen.                
                foreach act $activities_list {
                    set on_critical_path_p_arr($act) [expr { [lsearch -exact $cp_list $act] > -1 } ]
                    set count_on_cp_p_arr($act) [expr { $on_critical_path_p_arr($act) * $act_coef($act) } ]
                }
                # # # build base table
                ns_log Notice "acc_fin::scenario_prettify.2468: scenario '$scenario_tid' Build base report table."
                
                
                # Cells need this info for presentation: 
                #   activity_time_expected, time_start (branches_duration_max - time_expected),time_finish (branches_duration_max)
                #   activity_cost_expected, path_costs to complete activity
                #   direct dependencies
                # and some others for sorting.
                # Build a list of lists, where each row is an activity
                set p5_lists [list ]
                set p5_titles_list [acc_fin::pretti_columns_list p5 1]
                set path_counter 0
                set index_custom ""
                foreach path_dur_cost_len_list $paths_sort1_lists {
                    incr path_counter
                    set path_list [lindex $path_dur_cost_len_list 0]
                    set path_duration [lindex $path_dur_cost_len_list 1]
                    set path_cost [lindex $path_dur_cost_len_list 2]
                    set path_len [lindex $path_dur_cost_len_list 3]
                    set path_len_w_coefs [lindex $path_dur_cost_len_list 4]
                    # set act [lindex $path_list end]
                    set act_cp_ratio [expr { $act_count_on_cp / $path_len_w_coefs } ]
                    
                    if { !$error_time } {
                        set duration_ratio [expr { $path_duration / ( $cp_duration + 0. ) } ]
                    }
                    if { !$error_cost } {
                        set cost_ratio [expr { $path_cost / ( $cp_cost + 0. ) } ]
                    }

                    set path_act_counter 0
                    set act_count_on_cp 0
                    foreach act $path_list {
                        #set tree_act_cost_arr($act) $trunk_cost_arr($act)
                        incr path_act_counter
                        incr act_count_on_cp $count_on_cp_arr($act)
                        set has_direct_dependency_p [expr { $path_act_counter > 1 } ]
                        set on_a_sig_path_p [expr { $act_freq_in_load_cp_alts_arr($act) > $act_count_median } ]

                        #  0 activity_ref
                        #  1 path_len                  count of activities in path --was act count in tree activity_seq_num_arr() 
                        #  2 Q: Does this activity have any dependencies? ie predecessors
                        #  3 Q: Is this the CP?
                        #  4 Q: Is this activity referenced in more than a median number of times? on_a_sig_path_p
                        #  5 act_freq_in_load_cp_alts  count of activity is in a path or track
                        #  6 trunk_duration_arr        track duration
                        #  7 activity_time_expected    time expected of this activity
                        #  8 dependencies_larr         direct activity dependencies
                        #  9 act_cost_expected_arr     cost to complete activity
                        # 10 trunk_cost_arr            cost to complete path (including all path dependents)
                        # 11 path_counter
                        # 12 activity_seq              activity sequence number in path          
                        # 13 dependents_count_arr      count of dependent activities (in subtrees) --not inclusive of activity itself.
                        # 14 dep_act_seq               activity sequence considering all dependent activities. activity_seq_num_arr()
                        # 16 t_dc_source_arr           source of duration distribution curve via curve_import
                        # 17 c_dc_source_arr           source of cost distribution curve via curve_import

                        # base for p5
                        set activity_list [list $act $path_len $has_direct_dependency_p $on_critical_path_p_arr($act) $on_a_sig_path_p $act_freq_in_load_cp_alts_arr($act) $trunk_duration_arr($act) $act_time_expected_arr($act) $dependencies_larr($act) $act_cost_expected_arr($act) $trunk_cost_arr($act) $path_counter $path_act_counter $dependents_count_arr($act) $act_seq_num_arr($act) $t_dc_source_arr($act) $c_dc_source_arr($act) $index_custom ]
                        lappend p5_lists $activity_list
                    }


                }
                
                # # # PRETTI sorts
                ns_log Notice "acc_fin::scenario_prettify.2504: scenario '$scenario_tid' PRETTI sorts."

                # primary sort
                if { !$error_time } {
                    # critical path is the longest expected duration of dependent activities
                    # sort by path duration descending
                    set primary_sort_lists [lsort -decreasing -real -index 6 $p5_lists]
                } elseif { !$error_cost } {
                    # critical path is largest cost..
                    set primary_sort_lists [lsort -decreasing -real -index n $second_sort_lists]
                } else {
                    # critical path is longest path
                    set primary_sort_lists []
                }
                ns_log Notice "acc_fin::scenario_prettify.2516: scenario '$scenario_tid' primary_sort_lists $primary_sort_lists"



                        # build p4
                        
                        
                        #  0 path_list
                        # 16 path_duration
                    # 17 path_cost
                        # path_len
                        #   path_len_w_coefs
                        
                        #  1 path_act_counter                    count of activities in path --was act count in tree activity_seq_num_arr() 
                        #  2 act_pct_on_cp               Q: percent by count of this path's activities on the CP. CP = 100%
                        #  3 cost_ratio               path_cost / cp_cost       Q: percent of this path's cost over total projected cost.
                        #  4 on_critical_path_p          Q: Is this the CP?
                    #  5 duration_ratio           path_duration / cp_duration Q: percent of this path's duration on the CP. CP = 100%
                   
                    #  7 trunk_duration_arr          track duration
                    #  8 activity_time_expected      time expected of this activity
                    #  9 dependencies_larr           direct activity dependencies
                    # 10 act_cost_expected_arr       cost to complete activity
                    # 11 trunk_cost_arr              cost to complete path (including all path dependents)
                    # 12 path_counter
     
                    # 14 dependents_count_arr        count of dependent activities (in subtrees) --not inclusive of activity itself.
                    # 15 dep_act_seq                 activity sequence considering all dependent activities. activity_seq_num_arr()


                    # 18 index_eq_value
                    #### how do activity stats fit in context with creating html?  Rebuild p4 in context similar to p5 (ie inside act loop).
               #?? 13 activity_seq                activity sequence number in path          
  #??  6 act_freq_in_load_cp_alts    count of activity is in a path or track
                    set path_x_list [list $path_list $path_duration $path_cost $path_len $has_direct_dependency_p $on_critical_path_p $on_a_sig_path_p $act_freq_in_load_cp_alts_arr($act) $trunk_duration_arr($act) $act_time_expected_arr($act) $dependencies_larr($act) $act_cost_expected_arr($act) $trunk_cost_arr($act) $path_counter $path_act_counter $dependents_count_arr($act) $act_seq_num_arr($act) ]
                    lappend path_expanded_lists $path_x_list

    # p4_lol consists of first row (a list item):
    # (list track_1 track_2 track_3 ... track_N )
    # subsequent rows (list items):
    # (list cell_r1c1 cell_r1c2 cell_r1c3 ... cellr1cN )
    # ...
    # (list cell_rMc1 cell_rMc2 cell_rMc3 ... cellrMcN )
    # for N tracks of a maximum of M rows.
    # Each cell is an activity.
    # Each column is a track
    # Track_1 is CP

    # empty cells have empty string value.
    # other cells will contain comment format from acc_fin::scenario_prettify
    # "$activity "
    # "t:[lindex $track_list 7] "
    # "ts:[lindex $track_list 6] "
    # "c:[lindex $track_list 9] "
    # "cs:[lindex $track_list 10] "
    # "d:($depnc_larr(${activity})) "
    # "<!-- [lindex $track_list 4] [lindex $track_list 5] --> "



                set scenario_stats_list [qss_table_stats $scenario_tid]
                set scenario_name [lindex $scenario_stats_list 0]
                if { [llength $t_moment_list ] > 1 } {
                    set t_moment_len_list [list ]
                    foreach moment $t_moment_list {
                        lappend t_moment_len_list [string length $moment]
                    }
                    set t_moment_format "%1.f"
                    append t_moment_format [expr { [f::max $t_moment_len_list] - 2 } ]
                    lappend " t=[format ${t_moment_format} ${t_moment}]"
                }
                if { [llength $c_moment_list ] > 1 } {
                    set c_moment_len_list [list ]
                    foreach moment $c_moment_list {
                        lappend c_moment_len_list [string length $moment]
                    }
                    set c_moment_format "%1.f"
                    append c_moment_format [expr { [f::max $t_moment_len_list] - 2 } ]
                    lappend " c=[format ${c_moment_format} ${c_moment}]"
                }
                set scenario_title [lindex $scenario_stats_list 1]
                
                set time_end [clock seconds]
                set time_diff_secs [expr { $time_end - $time_start } ]
                set setup_diff_secs [expr { $setup_end - $setup_start } ]
                # the_time Time calculation completed
                set p1_arr(the_time) [clock format [clock seconds] -format "%Y %b %d %H:%M:%S"]
                # comments should include cp_duration, cp_cost, max_act_count_per_track 
                # time_probability_moment, cost_probability_moment, 
                # scenario_name, processing_time, time/date finished processing
                set comments "Scenario report for ${scenario_title}: "
                append comments "scenario_name ${scenario_name} , cp_duration_at_pm ${cp_duration} , cp_cost_pm ${cp_cost} ,"
                append comments "max_act_count_per_track ${act_count_max} , time_probability_moment ${t_moment} , cost_probability_moment ${c_moment} ,"
                append comments "setup_time ${setup_diff_secs} , main_processing_time ${time_diff_secs} seconds , time/date finished processing $p1_arr(the_time) "
                
                
                if { $p1_arr(db_format) ne "" } {
                    # Add titles before saving as p5 table
                    set primary_sort_lists [lreplace $primary_sort_lists 0 0 $p5_titles_list]
                    qss_table_create $primary_sort_lists "${scenario_name}.p5" "${scenario_title}.p5" $comments "" p5 $instance_id $user_id
                }
                
                # save as a new table of type PRETTI 
                append comments "color_mask_sig_idx 3 , color_mask_oth_idx 5 , colorswap_p 0"
                
                # max activity account per track = $act_count_max
                # whereas
                # each PRETTI table uses standard delimited text file format.
                # Need to convert into rows ie.. transpose rows of each column to a track with column names: track_(1..N). track_1 is CP
                # trac_1 track_2 track_3 ... track_N
                
                set pretti_lists [list ]
                set title_row_list [list ]
                set track_num 1
                    
                    #  0 activity_ref
                    #  1 activity_seq_num_arr() ie count of activities in track
                    #  2 Q: Does this activity have any dependencies? ie predecessors
                    #  3 Q: Is this the CP?
                    #  4 Q: Is this activity referenced in more than a median number of times?
                    #  5 act_freq_in_load_cp_alts  count of activity is in a path or track
                    #  6 trunk_duration_arr              track duration
                    #  7 act_time_expected_arr    time expected of this activity
                    #  8 dependencies_larr                direct activity dependencies
                    #  9 act_cost_expected_arr         cost to complete activity
                    # 10 trunk_cost_arr                  cost to complete path (including all path dependents)

                foreach track_list [lrange $primary_sort_lists 1 end] {
                    # each primary_sort_lists is a track:
                    # activity_ref  is the last activity_ref in the tracks
                    set activity_ref [lindex $track_list 0]
                    # activity_seq_num 
                    # dependencies_q cp_q significant_q popularity waypoint_duration activity_time 
                    # direct_dependencies activity_cost waypoint_cost
                    

                    #### So, column looping should include track_activity_lists as well as primary_sort_lists... see paths_arr()
                    ## and each subtrack should be analyzed to see if on CP, significant etc. ie recalced for index 4 and 5 of primary_sort_lists..

                    set track_activity_lists $subtrees_larr(${activity_ref})
                    set track_name "track_${track_num}"
                    lappend title_row_list $track_name
                    # in PRETTI table, each track is a column, so each row is built from each column, each column lappends each row..
                    # store each row in: row_larr()
                    for {set i 0} {$i < $act_count_max} {incr i} {
                        set row_larr($i) [list ]
                    }
                    for {set i 0} {$i < $act_count_max} {incr i} {
                        set activity [lindex $track_activity_list $i]
                        if { $activity ne "" } {
                            # cell should contain this info: "$act t:${time_expected} T:${branches_duration_max} D:${dependencies} "
                            set cell "$activity "
                            append cell "t:[lindex $track_list 7] "
                            append cell "ts:[lindex $track_list 6] "
                            append cell "c:[lindex $track_list 9] "
                            append cell "cs:[lindex $track_list 10] "
                            append cell "d:($dependencies_larr(${activity})) "
                            append cell "<!-- [lindex $track_list 4] [lindex $track_list 5] --> "
                            lappend row_larr($i) $cell
                        } else {
                            lappend row_larr($i) ""
                        }
                    }
                    incr track_num
                }
                # combine the rows
                lappend pretti_lists $title_row_list
                for {set i 0} {$i < $act_count_max} {incr i} {
                    lappend pretti_lists $row_larr($i)
                }
                qss_table_create $pretti_lists "${scenario_name}.p4" ${scenario_title} $comments "" p4 $instance_id $user_id
                # Comments data will be interpreted for determining standard deviation for determining cell highlighting
            }
            # next c_moment
        }
        # next t_moment
    }
    ns_log Notice "acc_fin::scenario_prettify.2639: scenario '$scenario_tid' done."
    return !${error_fail}
}

ad_proc -public acc_fin::table_sort_y_asc {
    table_tid
    {instance_id ""}
    {user_id ""}
} {
    Creates a copy of a distribution curve (table) sorted by column Y in ascending order. Returns table_id or empty string if error.
} {
    if { $instance_id eq "" } {
        set instance_id [ad_conn package_id]
    }
    if { $user_id eq "" } {
        set user_id [ad_conn user_id]
    }
    set read_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege read]
    set table_id_new ""
    if { $read_p } {
        set create_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege create]
        if { !$create_p } {
            set write_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege write]
        }
        if { $create_p || $write_p } {
            set table_stats_list [qss_table_stats $table_tid]
            # name, title, comments, cell_count, row_count, template_id, flags, trashed, popularity, time last_modified, time created, user_id.
            set trashed_p [lindex $table_stats_list 7]
            set table_flags [lindex $table_stats_list 6]
            set tid_user_id [lindex $table_stats_list 11]
            if { $table_flags eq "dc" && !$trashed_p } {
                set table_lists [qss_table_read $table_tid ]
                set title_row [lindex $table_lists 0]
                set y_idx [lsearch -exact $title_row "y"]
                if { $y_idx > -1 } {
                    set table_sorted_lists [lsort -index $y_idx -real [lrange $table_lists 1 end]]
                    set table_sorted_lists [linsert $table_sorted_lists 0 $title_row]
                    set table_stats [qss_table_stats $table_tid]
                    # name, title, comments, cell_count, row_count, template_id, flags, trashed, popularity, time last_modified, time created, user_id.
                    set table_name [lindex $table_stats 0]
                    set table_title [lindex $table_stats 1]
                    set table_comments [lindex $table_stats 2]
                    append table_comments " Sorted by Y on [lc_time_system_to_conn [clock format [clock seconds] -format "%Y-%m-%d %r"]]"
                    set table_template_id [lindex $table_stats 5]
                    set table_flags [lindex $table_stats_list 6]
                    set table_id_new [qss_table_create $table_sorted_lists $table_name $table_title $table_comments $table_template_id $table_flags $instance_id $user_id]
                }
            }
        }
    } 
    return $table_id_new
}
