package croxit.geo;
import croxit.core.Loader;
import croxit.core.Events;
import croxit.geo.LocationError;

class Location
{
	private static var last:Null<Position>;
	
#if CROXIT_MULTI_THREADED
	/**
	 * If in a multi-threaded environment, the position updates must go through a lock
	 */
	private static var mutex:cpp.vm.Mutex;
#end
	
	public static var update(default, null):hsl.haxe.Signaler<Position>;
	
	public static var error(default, null):hsl.haxe.Signaler<LocationError>;
	
	/**
	 *  Value that ranges from 0 to 4, which indicates the requested magnitude of precision, in Meters
	 *  (0 - 1m, 1 - 10m, 2 - 100m, 3 - 1000m, 4 - lowest)
	 * 	-1 is a special identifier, which uses Best for Navigation on iOs 4+
	 **/
	public static var precisionMagnitudeMeters(get_precisionMagnitudeMeters, set_precisionMagnitudeMeters):Int;
	
	/**
	 *  Distance filter is the minimum distance (in meters) that issues an update
	 **/
	public static var distanceFilterMeters(get_distanceFilterMeters, set_distanceFilterMeters):Float;
	
	/**
	 *  The Location manager can store the last fixes automatically;
	 *  This will change up to how many should be stored
	 */
	public static var lastPositionsStorageLength:Int = 1;
	
	private static var lastPositions:List<Position> = new List();
	
	/**
	 * Current Location Manager status
	 */
	public static var status(get_status, null):croxit.geo.LocationStatus;
	
	/**
	 * Gets last position values sent. The length of this array will be defined by lastPositionsStorageLength, 
	 * and it will be sorted with the most recent one first.
	 * @return
	 */
	public static function getLastPositions():Array<Position>
	{
		doLock(true);
		var ret = Lambda.array(lastPositions);
		doLock(false);
		ret.reverse();
		return ret;
	}
	
	/**
	 * Starts monitoring Location.
	 */
	public static function startMonitoring(?purpose:String):Void
	{
		_set_active(true, purpose);
	}
	
	/**
	 *  Stops monitoring location. Status will go back to being 'off'
	 */
	public static function stopMonitoring():Void
	{
		_set_active(false, null);
	}
	
	/**
	 * Only monitor significant changes. Works on the background
	 */
	public static function startMonitoringSignificant():Void
	{
		_set_active_significant(true);
	}
	
	/**
	 * Stop monitoring significant changes
	 */
	public static function stopMonitoringSignificant():Void
	{
		_set_active_significant(false);
	}
	
	/**
	 *  Returns the latest position received; Will return null if no position has been received yet.
	 * 	Note that this will not enable location tracking if it's disabled, it will only retrieve the latest if it's enabled already.
	 **/
	public static inline function getLatest():Null<Position>
	{
		return last;
	}
	
	/**
	 *  Sets the last location if it's newer than latest. Returns null if it's not latest
	 **/
	private static function setIfLatest(pos:Position):Null<Position>
	{
		doLock(true);
		var isLatest = false;
		if (last == null || pos.timeStamp > last.timeStamp)
		{
			last = pos;
			isLatest = true;
		}
		doLock(false);
		if (isLatest)
			return pos;
		else
			return null;
	}
	
	private static function get_precisionMagnitudeMeters():Int
	{
		return _getset_precision(null);
	}
	
	private static function set_precisionMagnitudeMeters(val:Int):Int
	{
		_getset_precision(val);
		return val;
	}
	
	private static function get_distanceFilterMeters():Float
	{
		return _getset_distfilter(null);
	}
	
	private static function set_distanceFilterMeters(val:Float):Float
	{
		_getset_distfilter(val);
		return val;
	}
	
	private static function get_status():LocationStatus
	{
		return Type.createEnumIndex(LocationStatus, _get_status());
	}
	
	private static #if !CROXIT_MULTI_THREADED inline #end function doLock(isLock:Bool) : Void
	{
#if CROXIT_MULTI_THREADED
		if (isLock)
			mutex.acquire();
		else
			mutex.release();
#end
	}
	
	static function __init__()
	{
#if CROXIT_MULTI_THREADED
		mutex = new cpp.vm.Mutex();
#end
		update = new hsl.haxe.DirectSignaler(Location, true);
		error = new hsl.haxe.DirectSignaler(Location, true);
		
		var _set_create_position = Loader.loadExt("croxit_geo", "cgeo_set_create_position", 1);
		
		_set_create_position(croxit.geo.Position.createArr);
		
		Events.addHandler("cgeo_location_update", function(loc:Position) {
			//check if location is valid
			doLock(true);
			if (!(
					(last != null && last.timeStamp >= loc.timeStamp) ||
					(loc.accuracy < 0)
				))
			{
				last = loc;
				lastPositions.add(loc);
				while(lastPositions.length > lastPositionsStorageLength)
					lastPositions.pop();
				update.dispatch(loc);
			}
			doLock(false);
		});
		
		Events.addHandler("cgeo_location_error", function(errorNumber, message) {
			doLock(true);
			var err = switch(errorNumber)
			{
				case 1:
					EDeniedByUser;
				case 2:
					ELocationUnknown;
				default:
					ECustom(message);
			};
			
			error.dispatch(err);
			doLock(false);
		});
		
	}
	
	private static var _set_active = Loader.loadExt("croxit_geo", "cgeo_set_active", 2);
	private static var _set_active_significant = Loader.loadExt("croxit_geo", "cgeo_set_active_significant", 1);
	private static var _getset_precision = Loader.loadExt("croxit_geo", "cgeo_getset_precision", 1);
	private static var _getset_distfilter = Loader.loadExt("croxit_geo", "cgeo_getset_distfilter", 1);
	private static var _get_status = Loader.loadExt("croxit_geo", "cgeo_status", 0);
}