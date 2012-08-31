package croxit.geo;

enum LocationError 
{
	ECustom(msg:String);
	EDeniedByUser;
	ELocationUnknown;
	//EHeadingFailure; TODO
}