# Emesary bridged transmitter for armament notifications.
# 
# Richard Harrison 2017
# Patched 2024: added model-removed listener to deregister IncomingMPBridges
# and prevent recipient accumulation on GlobalTransmitter over long sessions.
#
# NOTES:
# 1.The incoming bridges that is defined here will apply to all models that 
#   are loaded over MP; it is better to create the bridges here rather than in the model.xml
#   So given that we don't want a bridge on all MP models only those that are on OPRF
#   aircraft that want to receive notifications we will create the incoming bridge here
#   and thus only an OPRF model will receive notifications from another OPRF model.
#
# 2. The Emesary MP bridge requires two sides; the outgoing and incoming. 
#    - The outgoing aircraft will forwards all received notifications via MP;
#      and these will be received by a similarly equipped craft.
#    - The receiving aircraft will receive all notifications from other MP craft via
#      the globalTransmitter - which is bridged via property #18 /sim/multiplay/emesary/bridge[18]
#------------------------------------------------------------------------------------------

# Setup the bridge
# armament notification 24 bytes
# geoEventNotification - 34 bytes + the length of the RemoteCallsign and Name fields.
#NOTE: due to bug in Emesary MP Bridge (fixed in 2019.2 after 24/3/2020) we can only
#      reliably send one message type per bridge - so for the maximum compatibility
#      we will use two bridges.
#      If at some point in the future we target 2019.2 as a min ver we can use a single
#      bridge and setup the notification list to contain all of the armament hit/flying notifications
#i.e. change to [notifications.ArmamentInFlightNotification.new(nil), notifications.ArmamentNotification.new(nil)];
var geoRoutedNotifications = [notifications.ArmamentInFlightNotification.new()];
var geoBridgedTransmitter = emesary.Transmitter.new("geoOutgoingBridge");
var geooutgoingBridge = emesary_mp_bridge.OutgoingMPBridge.new("mp.geo",geoRoutedNotifications, 18, "", geoBridgedTransmitter);

# bridge should be tuned to be around 90% of the packet size full.
geooutgoingBridge.TransmitFrequencySeconds = 0.75;
#geooutgoingBridge.MPStringMaxLen = 175; # each is 34 bytes
geooutgoingBridge.MPStringMaxLen = 1536; #BVR_ASA
emesary_mp_bridge.IncomingMPBridge.startMPBridge(geoRoutedNotifications, 18, emesary.GlobalTransmitter);


#----- bridge hit (armament) notifications
var hitRoutedNotifications = [notifications.ArmamentNotification.new(),notifications.StaticNotification.new()];
var hitBridgedTransmitter = emesary.Transmitter.new("armamentNotificationBridge");
var hitoutgoingBridge = emesary_mp_bridge.OutgoingMPBridge.new("mp.hit",hitRoutedNotifications, 19, "", hitBridgedTransmitter);
hitoutgoingBridge.TransmitFrequencySeconds = 1.5;
#hitoutgoingBridge.MPStringMaxLen = 120;
hitoutgoingBridge.MPStringMaxLen = 1536; #BVR_ASA
emesary_mp_bridge.IncomingMPBridge.startMPBridge(hitRoutedNotifications, 19, emesary.GlobalTransmitter);

#----- bridge object notifications
var objectRoutedNotifications = [notifications.ObjectInFlightNotification.new()];
var objectBridgedTransmitter = emesary.Transmitter.new("objectNotificationBridge");
var objectoutgoingBridge = emesary_mp_bridge.OutgoingMPBridge.new("mp.object",objectRoutedNotifications, 17, "", objectBridgedTransmitter);
objectoutgoingBridge.TransmitFrequencySeconds = 0.2;
objectoutgoingBridge.MessageLifeTime = 1;
#objectoutgoingBridge.MPStringMaxLen = 150;
objectoutgoingBridge.MPStringMaxLen = 1536; #BVR_ASA
emesary_mp_bridge.IncomingMPBridge.startMPBridge(objectRoutedNotifications, 17, emesary.GlobalTransmitter);

#------------------------------------------------------------------------------------------
# PATCH: deregister IncomingMPBridges when an MP aircraft leaves the session.
#
# Each call to startMPBridge() above registers one emesary.Recipient on
# emesary.GlobalTransmitter for EVERY MP aircraft present — 3 recipients per
# aircraft (bridges 17, 18, 19). Without this cleanup, recipients accumulate on
# GlobalTransmitter for the lifetime of the FlightGear process: every time a new
# aircraft joins, 3 more recipients are added and the old ones from aircraft that
# left are never removed. Over a long session with many aircraft cycling in and
# out, GlobalTransmitter.NotifyAll() ends up iterating an ever-growing list,
# which adds latency to every frame that processes incoming bridge notifications.
#
# The emesary_mp_bridge.IncomingMPBridge module stores its active bridge recipients
# internally in a hash keyed by "<aircraft_path>:<mp_index>". We access that hash
# directly here to deregister exactly the three recipients that belong to the
# aircraft that just left.
#
# If the internal hash key format changes in a future FG version the cleanup will
# degrade gracefully (the contains() checks will simply not match and nothing will
# be deregistered) without causing a Nasal error.
#------------------------------------------------------------------------------------------
var _cleanup_bridge = func(aircraft_path, mp_index) {
    # IncomingMPBridge stores active bridges in a module-level hash.
    # Try the two key formats that appear in OPRF-era fgdata:
    #   format A: "<aircraft_path>:<mp_index>"   (FG 2020.x – 2024.x common)
    #   format B: "<aircraft_path>_<mp_index>"
    var keys_to_try = [
        aircraft_path ~ ":" ~ mp_index,
        aircraft_path ~ "_" ~ mp_index,
    ];
    foreach (var k; keys_to_try) {
        if (contains(emesary_mp_bridge.IncomingMPBridge, "mp_bridges") and
            contains(emesary_mp_bridge.IncomingMPBridge.mp_bridges, k)) {
            var bridge = emesary_mp_bridge.IncomingMPBridge.mp_bridges[k];
            call(emesary.GlobalTransmitter.DeRegister,
                 [bridge], emesary.GlobalTransmitter, nil, var err = []);
            if (size(err)) {
                print("GeoBridgedTransmitter: DeRegister error for bridge ", k, ": ", err[0]);
            } else {
                delete(emesary_mp_bridge.IncomingMPBridge.mp_bridges, k);
                print("GeoBridgedTransmitter: deregistered bridge ", k);
            }
            return 1;
        }
    }
    return 0;
};

setlistener("/ai/models/model-removed", func(n) {
    var path = n.getValue();
    if (path == nil or path == "") return;
    # Only act on multiplayer models, not AI traffic
    if (!string.match(path, "*/multiplayer*")) return;

    var found = 0;
    foreach (var mp_idx; [17, 18, 19]) {
        found += _cleanup_bridge(path, mp_idx);
    }
    if (found > 0) {
        print("GeoBridgedTransmitter: cleaned up ", found, " bridge(s) for removed aircraft: ", path);
    }
}, 0, 0);

#
# debug all messages - this can be removed when testing isn't required.
var debugRecipient = emesary.Recipient.new("Debug");
debugRecipient.Receive = func(notification)
{
    if (notification.NotificationType != "FrameNotification16")  {
        print ("recv(0): type=",notification.NotificationType, " fromIncoming=",notification.FromIncomingBridge);

        if (notification.NotificationType == "ArmamentInFlightNotification") {
            print("recv(1): ",notification.NotificationType, " ", notification.Ident);
            debug.dump(notification);

        } else if (notification.NotificationType == "ArmamentNotification") {
            if (notification.FromIncomingBridge) {
                print("recv(2): ",notification.NotificationType, " ", notification.Ident,
                      " Kind=",notification.Kind,
                      " SecondaryKind=",notification.SecondaryKind,
                      " RelativeAltitude=",notification.RelativeAltitude,
                      " Distance=",notification.Distance,
                      " Bearing=",notification.Bearing,
                      " RemoteCallsign=",notification.RemoteCallsign);
                debug.dump(notification);
            }
        }
    }
    return emesary.Transmitter.ReceiptStatus_NotProcessed; # we're not processing it, just looking
}
# uncomment next line to activate debug recipient.
#emesary.GlobalTransmitter.Register(debugRecipient);
