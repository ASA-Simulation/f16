#
# Avoid putting Nasal scripts into inputs.xml as people then copy them and put them in their joystick.
#  And when we change it, they forget to change their joystick, and their aircraft will not work as it should.
#
var autoMFDLastWeapon = nil;

var autoMFDForSelectedWeapon = func {
    if (pylons.fcs == nil) return;

    var wpn = pylons.fcs.getSelectedWeapon();
    if (wpn == nil) return;

    var wtype = wpn.type;

    # Evita ficar reconfigurando os MFDs a cada frame
    if (wtype == autoMFDLastWeapon) return;
    autoMFDLastWeapon = wtype;

    # AIM-120: esquerda FCR/CRM, direita HSD
    if (wtype == "AIM-120" or wtype == "AIM-ASA-120") {
        radar_system.apg68Radar.setRootMode(0); # CRM

        setprop("controls/armament/dual", 1);
        pylons.fcs.updateDual();
                       
        displays.leftMFD.system.selectPage("PageFCR");
        displays.rightMFD.system.selectPage("PageHSD");

        #screen.log.write("AUTO MFD: "~wtype~" -> L FCR/GM | R WPN/CCIP | PAIR", 0.5, 0.5, 1);
        return;
    }

    # Bombas: esquerda FCR/GM, direita WPN em CCIP
    if (wtype == "MK-82" or wtype == "MK-84" or wtype == "GBU-31") {
        radar_system.apg68Radar.setRootMode(3); # GM
        pylons.fcs.setDropMode(fc.DROP_CCIP);

        # Lançamento em pares
        setprop("controls/armament/dual", 2);
        pylons.fcs.updateDual();
        
        displays.leftMFD.system.selectPage("PageFCR");
        displays.rightMFD.system.selectPage("PageSMSWPN");

        #screen.log.write("AUTO MFD: AIM-120 -> L FCR/CRM | R HSD | SINGLE", 0.5, 0.5, 1);
        return;
    }
};

var autoMFDTick = func {
    autoMFDForSelectedWeapon();

    # Roda 5 vezes por segundo, leve o bastante
    settimer(autoMFDTick, 0.2);
};

var startAutoMFD = func {
    autoMFDLastWeapon = nil;
    settimer(autoMFDTick, 1.0);
};

var emerg_alt = func {
	if (getprop("payload/armament/msg")==1) {
        screen.log.write("CTRL-U disabled at the moment.");
    } else {
        setprop("position/altitude-ft", getprop("position/altitude-ft")+1000);
        setprop("sim/startup/onground", 0);
    }
                    
}

var speed_up = func {
	if (getprop("payload/armament/msg")==1) {
        screen.log.write("Speed-up disabled at the moment.");
    } else {
        controls.speedup(1);
    }
}

var speed_down = func {
	if (getprop("payload/armament/msg")) {
        screen.log.write("Speed-down disabled at the moment.");
    } else {
        controls.speedup(-1);
    }
}

var dogfight = func {        
	var dg = getprop("f16/avionics/dgft");
    dg = !dg;
    setprop("f16/avionics/dgft", dg);
    if (dg) {
        var prio = radar_system.apg68Radar.getPriorityTarget();
        setprop("instrumentation/radar/radar-enable-std", getprop("instrumentation/radar/radar-enable"));
        if (prio == nil) {
            setprop("instrumentation/radar/radar-enable", 0);
        }
        pylons.fcs.selectWeapon(fc.defaultCannon);
        ded.dataEntryDisplay.page = ded.pEWS;
        radar_system.apg68Radar.setRootMode(1, prio);
        displays.leftMFD.system.selectPage("PageFCR");
        displays.rightMFD.system.selectPage("PageSMSWPN");
        f16.setDefaultAAgunSight();#eegs
        if (pylons.fcs != nil and getprop("controls/armament/master-arm")) {
            foreach(var snake;pylons.fcs.getAllOfType("AIM-9L")) {
                snake.setCooling(1);
            }
            foreach(var snake;pylons.fcs.getAllOfType("AIM-9M")) {
                snake.setCooling(1);
            }
            foreach(var snake;pylons.fcs.getAllOfType("AIM-9X")) {
                snake.setCooling(1);
            }
        }
        #f16.rdrModeGM = 0;
        # BVR_ASA
        screen.log.write("Radar BVR "~(radar_system.apg68Radar.getRange())~"nm", 0.5, 0.5, 1);
    } else {
        radar_system.apg68Radar.setRootMode(0, radar_system.apg68Radar.getPriorityTarget());
        setprop("instrumentation/radar/radar-enable", getprop("instrumentation/radar/radar-enable") and getprop("instrumentation/radar/radar-enable-std"));
    }
    setprop("f16/avionics/dgft", dg); # extra invocation on purpose
}

var replay = func {
    if (getprop("payload/armament/msg")==1) {
        screen.log.write("Please do not use replay while in combat over MP!");
    } else {
        call(func{fgcommand('replay', props.Node.new({}))},nil,var err2 = []);
        call(func{fgcommand('dialog-show', props.Node.new({"dialog-name": "replay"}))},nil,var err2 = []);
    }

}

var radar_standby = func {
    # BVR_ASA
    if(getprop("instrumentation/radar/radar-enable") == 0) {
        setprop("instrumentation/radar/radar-enable", 0);
        setprop("instrumentation/radar/radar-enable-std", 1);
    }
    if(getprop("instrumentation/radar/radar-enable") == 1) {
        setprop("instrumentation/radar/radar-enable", 1);
        setprop("instrumentation/radar/radar-enable-std", 0);
    }
    screen.log.write("Radar "~(getprop("instrumentation/radar/radar-enable")==0?"SILENT":"ACTIVE")~" "~(getprop("instrumentation/radar/radar2-range")~"nm"), 0.5, 0.5, 1);
}

var masterarm = func {
	var variantID = getprop("/sim/variant-id");
    if ((variantID == 0 or variantID == 1 or variantID == 3) and getprop("controls/armament/master-arm-switch") == 0 and getprop("controls/armament/master-arm-cover-open") == 0) {
        setprop("controls/armament/master-arm-cover-open",1);
        screen.log.write("Master-arm cover open.", 0.5, 0.5, 1);
    } else {
        var now = getprop("controls/armament/master-arm-switch");
        now += 1;
        if (now > 1) {
            now = -1;
        }
        setprop("controls/armament/master-arm-switch", now);
        screen.log.write("Master-arm "~(getprop("controls/armament/master-arm-switch")==0?"OFF":(getprop("controls/armament/master-arm-switch")==1?"ON":"SIM")), 0.5, 0.5, 1);
    }
}

var chute_release = func {
	if (getprop("f16/chute/done")) {
        setprop("f16/chute/enable", 0);
        setprop("f16/chute/fold", 1);
        setprop("fdm/jsbsim/external_reactions/chute/magnitude", 0);
        f16.chuteRelease();
    }
}

var pause = func {
    #if (getprop("payload/armament/msg")) {
    #    screen.log.write("Please do not pause while in combat over MP!");
    #} else {
        setprop("/sim/freeze/master", !getprop("/sim/freeze/master"));
        setprop("/sim/freeze/clock", !getprop("/sim/freeze/clock"));
        if (getprop("/sim/freeze/master")) {
            screen.log.write("Sim is paused");
        } else {
            screen.log.write("Sim is resumed");
        }
    #}
}

var cycleW = props.globals.getNode("/controls/armament/weapon-selected", 1);
cycleW.setIntValue(0);
setlistener(cycleW, func (prop) {
    if (prop.getIntValue() == 1) pylons.fcs.cycleLoadedWeapon();
    if (prop.getIntValue() == -1) pylons.fcs.cycleBackLoadedWeapon();
});

var cycleT = props.globals.getNode("/controls/armament/target-selected", 1);
cycleT.setIntValue(0);
setlistener(cycleT, func (prop) {
    # Only TWS mode
    if (prop.getIntValue() == 1) radar_system.apg68Radar.cycleDesignate();
});


var cycleS = props.globals.getNode("/controls/armament/missile-reject", 1);
cycleS.setBoolValue(0);
setlistener(cycleS, func (prop) {
    if (prop.getIntValue() == 1) pylons.fcs.cycleStation();
});

controls.applyPickle = func (value) {
    var trigger = getprop("/controls/armament/trigger");
    if (value == 1 and trigger == 0) {
        setprop("/controls/armament/trigger", value);
    }
    if (value == 0 and trigger == 1) {
        setprop("/controls/armament/trigger", value);
    }
}

startAutoMFD();