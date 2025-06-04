set plugin_name "de1_water_tracker_plugin"

namespace eval ::plugins::${plugin_name} {

    variable author "Sy_Butter"
    variable contact "Github"
    variable version 0.1
    variable description "Track total water usage to help schedule filter changes."
    variable name "Water Usage Tracker"
    variable settings

    proc build_ui {} {
        variable settings

        set page_name "plugin_water_tracker_page_default"

        add_de1_page "$page_name" "settings_message.png" "default"
        add_de1_text $page_name 1280 1310 -text [translate "Done"] -font Helv_10_bold -fill "#fAfBff" -anchor "center"
        add_de1_button $page_name {say [translate {Done}] $::settings(sound_button_in); page_to_show_when_off extensions} 980 1210 1580 1410 ""

        add_de1_text $page_name 1280 300 -text [translate "Water Tracker"] -font Helv_20_bold -width 1200 -fill "#444444" -anchor "center" -justify "center"

        add_de1_variable $page_name 1280 600 -font global_font -width 800 -fill "#444444" -anchor "center" -textvariable {$::plugins::water_tracker::settings(display)}

        dui add entry $page_name 1280 760 -tags filter_date -width 12 -font Helv_10 \
            -borderwidth 1 -bg #fbfaff -foreground #4e85f4 -relief flat \
            -highlightthickness 1 -highlightcolor #000000 \
            -textvariable ::plugins::water_tracker::settings(filter_change_date) \
            -label [translate "Filter change date"] -label_pos {1280 700} \
            -label_font Helv_10_bold -label_width 1200 -label_fill "#444444" -label_anchor center

        dui add dcheckbox $page_name 1280 860 -tags use_gallons -textvariable ::plugins::water_tracker::settings(use_gallons) -fill "#444444" \
            -label [translate "Display in gallons"] -label_font Helv_10_bold -label_fill #4e85f4 -command ::plugins::water_tracker::toggle_units

        add_de1_text $page_name 1280 1000 -text [translate "Reset Counter"] -font Helv_10_bold -fill "#4e85f4" -anchor "center"
        add_de1_button $page_name ::plugins::water_tracker::reset_counter 980 970 1580 1070 ""

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
        } else {
            set value [expr {$settings(total_volume) / 1000.0}]
            set units "L"
        }
        set settings(display) [format [translate "Total water used: %.2f %s\nFilter changed: %s"] $value $units $date_text]
    }

    proc reset_counter {} {
        variable settings
        set settings(total_volume) 0
        set settings(filter_change_date) [clock format [clock seconds] -format "%Y-%m-%d"]
        save_plugin_settings $::plugins::water_tracker::plugin_name
        update_display
        popup [translate "Counter reset"]
    }

    proc toggle_units {} {
        save_plugin_settings $::plugins::water_tracker::plugin_name
        update_display
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
                    save_plugin_settings $::plugins::water_tracker::plugin_name
                    update_display
                }
            }
        }
    }

    proc main {} {
        variable settings
        if {[array size settings] == 0} {
            array set settings { total_volume 0 filter_change_date "" use_gallons 0 }
        } else {
            if {![info exists settings(filter_change_date)]} {
                set settings(filter_change_date) ""
            }
            if {![info exists settings(use_gallons)]} {
                set settings(use_gallons) 0
            }
        }
        update_display
        ::de1::event::listener::on_major_state_change_add ::plugins::water_tracker::on_state_change

        plugins gui water_tracker [build_ui]
    }
}