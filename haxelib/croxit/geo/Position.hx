package croxit.geo;

class Position
{
	public var latitude(default, null):Float;
	public var longitude(default, null):Float;
	public var altitude(default, null):Float;
	
	/**
	 *  Accuracy is measured in Meters
	 **/
	public var accuracy(default, null):Float;
	public var altitudeAccuracy(default, null):Float;
	
	/**
	 *  Direction of travel
	 **/
	public var heading(default, null):Float;
	public var speed(default, null):Float;
	
	public var timeStamp(default, null):Float;
	
	private function new():Void
	{
		
	}
	
	public static function create(latitude, longitude, altitude, accuracy, altAccuracy, heading, speed, timeStamp):Position
	{
		var ret = new Position();
		ret.latitude = latitude;
		ret.longitude = longitude;
		ret.altitude = altitude;
		ret.accuracy = accuracy;
		ret.altitudeAccuracy = altAccuracy;
		ret.heading = heading;
		ret.speed = speed;
		ret.timeStamp = timeStamp;
		return ret;
	}
	
	public static function createArr(arr:Array<Dynamic>):Position 
	{
		return create(arr[0], arr[1], arr[2], arr[3], arr[4], arr[5], arr[6], arr[7]);
	}
	
	
	public function toString():String
	{
		return "[Position: " + latitude + ", " + longitude + "(" + accuracy + ")]";
	}
}