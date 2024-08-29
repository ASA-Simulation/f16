# this is temporary and not using emesary
var pylon = 0;

var hasSpace = func(s) {
    for (var i = 0; i < size(s); i += 1) {
        if (string.isspace(s[i])) {
            return 1;
        }
    }
    return 0;
}

var typeID2emesaryID =  func (typeID) {
	if (typeID <= 100) {
	return typeID + 21;
	} elsif (typeID <= 180) {
	return (typeID - 100) * -1 - 40;
	} else {
	print("Missile TypeID too large value, max is 180");
	return 0;
	}
}

var checkArmament = func {
	var str11 = "";
	for(var i=0;i<12;i=i+1){
		var type = getprop("payload/armament/station/id-"~i~"-type") or "";
		if(!string.isblank(type) and !hasSpace(type))
		{
			var id = getprop("payload/armament/"~string.lc(type)~"/type-id");
			if(id!=nil){
				id = typeID2emesaryID(id);
				str11~=	sprintf("%d", id);

			}
			str11~= ",";
		}
	}
	setprop("sim/multiplay/generic/string[11]", str11);
}

var loop = func {
	if (!getprop("sim/replay/replay-state")) {
		pylon += 1;
		if (pylon == 12) {
			pylon = 0;
		}
		var type = getprop("payload/armament/station/id-"~pylon~"-type") or "";
		var count = getprop("payload/armament/station/id-"~pylon~"-count") or 0;
		var set = getprop("payload/armament/station/id-"~pylon~"-set");
		setprop("sim/multiplay/generic/string[5]", sprintf("%02d--%s++%02d--%s",pylon,type,count,set));
		checkArmament();
	}
	settimer(loop, 0.25);
}
