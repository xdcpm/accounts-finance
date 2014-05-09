ad_library {

    PRETTI example data used for Project Reporting Evaluation and Track Task Interpretation
    @creation-date 8 May 2014
    @cvs-id $Id:
    @Copyright (c) 2014 Benjamin Brink
    @license GNU General Public License 3, see project home or http://www.gnu.org/licenses/gpl-3.0.en.html
    @project home: http://github.com/tekbasse/accounts-finance
    @address: po box 20, Marylhurst, OR 97036-0020 usa
    @email: kappa@dekka.com
    
Finance Package is 

}

namespace eval acc_fin {}

ad_proc -public acc_fin::example_table {
    {table_ref ""}
} {
    Returns a list of 3 items. index 0 is table title; index 1 is table description, index 2 is table in data entry format, commas between columns, spaces between multiple items in same row and column;  
} {
    set ret_list ""
    switch -exact $table_ref {
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
            #      cost_probability_moment A percentage (0..1) along the (cumulative) distribution curve
            #set ret_list \[list name value\]
            set ret_list [list activity_table_tid activity_table_name task_types_tid task_types_name time_dist_curve_name time_dist_curve_tid cost_dist_curve_name cost_dist_curve_tid time_est_short time_est_median time_est_long time_probability_moment cost_est_low cost_est_median cost_est_high cost_probability_moment]
        }
        p11 {
            #set ret_list \[list name value\]
            set ret_list [list activity_table_tid ]
        }
        p20a {
            set ret_list [list "Wikipedia PERT" "This is an example from PERT entry of Wikipedia. See entry for details: http://en.wikipedia.org/wiki/Program_Evaluation_and_Review_Technique" "activity_ref,time_est_short,time_est_med,time_est_long,time_ext\n
A,2,4,6,4.0\n
B,3,5,9,5.33\n
C,4,5,7,5.17\n
D,4,6,10,6.33\n
E,4,5,7,5.17\n
F,3,4,8,4.5\n
G,3,5,8,5.17\n"
            # p2 Task Network
            #      activity_ref           reference for an activity, a unique task id, using "activity" to differentiate between table_id's tid 
            #                             An activity reference is essential a function as in f() with no attributes,
            #                             However, there is room to grow this by extending a function to include explicitly set paramemters
            #                             within the function, similar to how app-model handles functions aka vectors
            #                             The multiple of an activity is respresented by a whole number followed by an "*" 
            #                             with no spaces between (when spaces are used as an activity delimiter), or
            #                             with spaces allowed (when commas or another character is used as an activity delimiter.
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
            set ret_list [list activity_ref aid_type dependent_tasks name description max_concurrent max_overlap_pct time_est_short time_est_median time_est_long time_dist_curve_tid time_dist_curve_name time_probability_moment cost_est_low cost_est_median cost_est_high cost_dist_curve_tid cost_dist_curve_name cost_probability_moment]

        }
        p21 {
            set ret_list [list activity_ref dependent_tasks]
        }
        p30 {
            # p3 Task Types:   
            #      type
            #      dependent_types      Other dependent types required by this type. (possible reference collisions. type_refs != activity_refs.
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
            set ret_list [list type dependent_tasks dependent_types name description max_concurrent max_overlap_pct activity_table_tid activity_table_name task_types_tid task_types_name time_dist_curve_name time_dist_curve_tid cost_dist_curve_name cost_dist_curve_tid time_est_short time_est_median time_est_long time_probability_moment cost_est_low cost_est_median cost_est_high cost_probability_moment db_format]            
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

            set ret_list [list activity_ref activity_seq_num dependencies_q cp_q significant_q popularity waypoint_duration activity_time direct_dependencies activity_cost waypoint_cost]
        }
        p51 {
            # each row is a cell, in format of detailed PRETTI internal output. See code. 
            set ret_list [list activity_ref activity_seq_num dependencies_q cp_q significant_q popularity waypoint_duration activity_time direct_dependencies activity_cost waypoint_cost]
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
