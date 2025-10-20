set plugin_name "de1_water_tracker"

namespace eval ::plugins::${plugin_name} {
    variable author "Sy_Butter"
    variable contact "Github"
    variable version 0.2
    variable description "Track total water usage and get notified when it's time to change your filter."
    variable name "Water Usage Tracker"
    variable settings

    proc build_ui {} {
        variable settings
        set page_name "plugin_water_tracker_page_default"

        add_de1_page "$page_name" "settings_message.png" "default"
        add_de1_text $page_name 1280 1310 -text [translate "Done"] -font Helv_10_bold -fill "#fAfBff" -anchor "center"
        add_de1_button $page_name {say [translate {Done}] $::settings(sound_button_in); ::plugins::de1_water_tracker::save_and_close} 980 1210 1580 1410 ""

        add_de1_text $page_name 1280 300 -text [translate "Water Tracker"] -font Helv_20_bold -width 1200 -fill "#444444" -anchor "center" -justify "center"

        add_de1_variable $page_name 1280 600 -font global_font -width 800 -fill "#444444" -anchor "center" -textvariable {$::plugins::de1_water_tracker::settings(display)}

        dui add entry $page_name 1280 760 -tags filter_date -width 12 -font Helv_10 \
            -borderwidth 1 -bg #fbfaff -foreground #4e85f4 -relief flat \
            -highlightthickness 1 -highlightcolor #000000 \
            -textvariable ::plugins::de1_water_tracker::settings(filter_change_date) \
            -label [translate "Filter Last Changed Date"] -label_pos {1280 700} \
            -label_font Helv_10_bold -label_width 1200 -label_fill "#444444" -label_anchor center

        dui add dcheckbox $page_name 1280 890 -tags use_gallons -textvariable ::plugins::de1_water_tracker::settings(use_gallons) -fill "#444444" \
            -label [translate "Display in gallons"] -label_font Helv_10_bold -label_fill #4e85f4 -command ::plugins::de1_water_tracker::toggle_units

        dui add entry $page_name 1280 1010 -tags filter_threshold -width 12 -font Helv_10 \
            -borderwidth 1 -bg #fbfaff -foreground #4e85f4 -relief flat \
            -highlightthickness 1 -highlightcolor #000000 \
            -textvariable ::plugins::de1_water_tracker::settings(filter_threshold_display) \
            -label [translate "Filter change reminder (L or gal)"] -label_pos {1280 950} \
            -label_font Helv_10_bold -label_width 1200 -label_fill "#444444" -label_anchor center

        add_de1_text $page_name 1280 1150 -text [translate "Reset Counter"] -font Helv_10_bold -fill "#4e85f4" -anchor "center"
        add_de1_button $page_name ::plugins::de1_water_tracker::reset_counter 980 1120 1580 1220 ""

        return $page_name
    }

    proc update_display {} {
        variable settings
        set date_text $settings(filter_change_date)
        if {$date_text eq ""} {
            set date_text [translate "Unknown"]
        }
        if {[info exists settings(use_gallons)] && $settings(use_gallons)} {
            set value [expr {$settings(total_volume) / 3785.41}]
            set units "gal"
            # Update threshold display
            if {$settings(filter_threshold_ml) > 0} {
                set settings(filter_threshold_display) [format "%.1f" [expr {$settings(filter_threshold_ml) / 3785.41}]]
            }
        } else {
            set value [expr {$settings(total_volume) / 1000.0}]
            set units "L"
            # Update threshold display
            if {$settings(filter_threshold_ml) > 0} {
                set settings(filter_threshold_display) [format "%.1f" [expr {$settings(filter_threshold_ml) / 1000.0}]]
            }
        }
        set settings(filter_change_date) [string trim $settings(filter_change_date)]
        set settings(display) [format [translate "Total water used: %.2f %s\nFilter last changed: %s"] $value $units $date_text]
    }

    proc update_threshold {} {
        variable settings
        # Convert display value to milliliters based on current unit
        if {[catch {
            set threshold_value [string trim $settings(filter_threshold_display)]
            set old_threshold [expr {[info exists settings(filter_threshold_ml)] ? $settings(filter_threshold_ml) : 0}]

            if {$threshold_value eq "" || $threshold_value == 0} {
                set settings(filter_threshold_ml) 0
            } else {
                if {$settings(use_gallons)} {
                    set settings(filter_threshold_ml) [expr {$threshold_value * 3785.41}]
                } else {
                    set settings(filter_threshold_ml) [expr {$threshold_value * 1000.0}]
                }
            }

            # If threshold changed, reset notification flag so user can be notified again
            if {$old_threshold != $settings(filter_threshold_ml)} {
                set settings(notification_shown) 0
            }

            save_plugin_settings de1_water_tracker
        }]} {
            # Invalid input, reset to current value
            update_display
        }
    }

    proc check_threshold {} {
        variable settings

        # Convert the display value to ml before checking (in case user just entered it)
        update_threshold

        # Only check if threshold is set and notification hasn't been shown
        if {$settings(filter_threshold_ml) > 0 && !$settings(notification_shown)} {
            if {$settings(total_volume) >= $settings(filter_threshold_ml)} {
                set settings(notification_shown) 1
                save_plugin_settings de1_water_tracker

                # Determine units for notification
                if {$settings(use_gallons)} {
                    set threshold_display [format "%.1f gal" [expr {$settings(filter_threshold_ml) / 3785.41}]]
                } else {
                    set threshold_display [format "%.1f L" [expr {$settings(filter_threshold_ml) / 1000.0}]]
                }

                popup [translate "Filter change reminder: You've reached $threshold_display of water usage!"]
            }
        }
    }

    proc reset_counter {} {
        variable settings
        set settings(total_volume) 0
        set settings(filter_change_date) [clock format [clock seconds] -format "%Y-%m-%d"]
        set settings(notification_shown) 0
        save_plugin_settings de1_water_tracker
        update_display
        popup [translate "Counter reset"]
    }

    proc toggle_units {} {
        variable settings
        # When toggling units, convert the threshold stored in ml to the new unit for display
        update_display
        save_plugin_settings de1_water_tracker
    }

    proc save_and_close {} {
        variable settings
        # Save the threshold value before closing
        update_threshold
        page_to_show_when_off extensions
    }

    proc on_state_change {event_dict} {
        variable settings
        set this_state [dict get $event_dict this_state]
        set prev_state [dict get $event_dict previous_state]

        if { $this_state eq "Idle" } {
            switch -exact -- $prev_state {
                Espresso -
                HotWater -
                HotWaterRinse -
                SteamRinse -
                Steam -
                Refill -
                Clean -
                Descale -
                AirPurge {
                    set settings(total_volume) [expr {$settings(total_volume) + $::de1(volume)}]
                    save_plugin_settings de1_water_tracker
                    update_display
                    check_threshold
                }
            }
        }
    }

    proc main {} {
        variable settings
        if {[array size settings] == 0} {
            array set settings {
                total_volume 0
                filter_change_date ""
                use_gallons 0
                filter_threshold_ml 0
                filter_threshold_display "0"
                notification_shown 0
            }
        } else {
            if {![info exists settings(filter_change_date)]} {
                set settings(filter_change_date) ""
            }
            if {![info exists settings(use_gallons)]} {
                set settings(use_gallons) 0
            }
            if {![info exists settings(filter_threshold_ml)]} {
                set settings(filter_threshold_ml) 0
            }
            if {![info exists settings(filter_threshold_display)]} {
                set settings(filter_threshold_display) "0"
            }
            if {![info exists settings(notification_shown)]} {
                set settings(notification_shown) 0
            }
        }
        update_display
        ::de1::event::listener::on_major_state_change_add ::plugins::de1_water_tracker::on_state_change

        plugins gui de1_water_tracker [build_ui]
    }
}