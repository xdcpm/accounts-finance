# requires instance_id table_tid
# optional user_id

#set package_id [ad_conn package_id]
set user_id [ad_conn user_id]
set read_p [permission::permission_p -party_id $user_id -object_id $instance_id -privilege read]

if { [qf_is_natural_number $table_tid] } {
    set table_stats_list [qss_table_stats $table_tid]
    # name, title, comments, cell_count, row_count, template_id, flags, trashed, popularity, time last_modified, time created, user_id
    set table_name [lindex $table_stats_list 0]
    set table_title [lindex $table_stats_list 1]
    set table_comments [lindex $table_stats_list 2]
    set table_flags [lindex $table_stats_list 6]
#    set table_html "<h3>${table_title} (${table_name})</h3>\n"
    set table_lists [qss_table_read $table_tid]
    set table_text [qss_lists_to_text $table_lists]
    set table_tag_atts_list [list border 1 cellpadding 3 cellspacing 0]
    if { $table_flags eq "p4" } {
        set table_html [acc_fin::pretti_table_to_html $table_lists $table_comments]
    } else {
        if { $table_flags eq "dc" } {
            set table_titles_list [lindex $table_lists 0]
            set table_data_list [lrange $table_lists 1 end]
            set x_idx [lsearch -exact $table_titles_list "x"]
            set y_idx [lsearch -exact $table_titles_list "y"]
            if { $x_idx > -1 && $y_idx > -1 && [llength $table_data_list] > 0 } {
                # set alternating colors

                # verify images exist. if not, make them.
                # from mad-lab-lib
                if { ![file exists $filename] } {
                    # Create canvas image 
                    # to create a solid red canvas image:                                                                                              
                    # gm convert -size 640x480 "xc:#f00" canvas.png                                                                                    
                    # from: www.graphicsmagick.org/FAQ.html                                                                                           
                    # Assume the same border for the farsides. It may be easier for a user to clip than to add margin.                                
                    # exec gm convert -size "200x200" -fill "#000000" -stroke "#ff0000" -draw "ellipse 100,100 100,100 0,90" "xc:#ffffff" test19.png
                    # exec gm convert -size "200x200" -fill "#000000" -stroke "#000000" -draw "path 'M 100 100 L 100 200 L 200 100 L 100 100'" test19.png test19.png
                    # given origin: x0,y0 arc from x1,y1 to x2,y2 with radius r1, color c1
                    # exec gm convert -size "200x200" -fill $c1 -stroke $c1 -draw "ellipse $x0,$y0 $r1,$r1 0,90" "xc:#ffffff" test19.png
                    # exec gm convert -size "200x200" -fill $c1 -stroke $c1 -draw "path 'M $x0 $y0 L $x1 $y1 L $x2 $y2 L $x0 $y0'" test19.png test19.png
             
                    set width_px [expr { $x2 + 2 * $x1 } ]
                    set height_px [expr { $y2 + 2 * $y1 } ]
                    puts "Creating ${width_px}x${height_px} image: $filename"
                    exec gm convert -size ${width_px}x${height_px} "xc:#ffffff" $filename
                }


                if { 1 } {
                    # style cobbler (square pie) chart
                    # make chart using html
                    # acs-subsite/www/resources/spacer.gif is a transparent 1 pixel image available by default.
                } else {
                    # style pie chart
                    # use gm draw elipse ( 100,100 100,150 0,360) <- from unseen example
                }
            }
        }
        set table_html [qss_list_of_lists_to_html_table $table_lists $table_tag_atts_list]
        #    append table_html "<p>${table_comments}</p>"
        set table_log_messages_list [acc_fin::pretti_log_read $table_tid 3 $user_id $instance_id]
        if { [llength $table_log_messages_list] > 0 } {
            set message_html "<h3>Most Recent Activity Log</h3><ul>"
            foreach message $table_log_messages_list {
                append message_html "<li>"
                append message_html $message
                append message_html "</li>"
            }
            append message_html "</ul>"
            append table_comments $message_html
        }
    }
}
