import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// info about whats happening with the background process
var counter=0;
var bgdata="none";
var canDoBG=false;
var inBackground=false;			//new 8-27
// keys to the object store data
var OSCOUNTER="oscounter";
var OSDATA="osdata";


class watchApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    	var now = System.getClockTime();
    	var ts = now.hour+":"+now.min.format("%02d");
    	//you'll see this gets called in both the foreground and background        
        System.println("App initialize "+ts);
        var temp = Application.getApp().getProperty(OSCOUNTER);
        //var temp=null;
        if(temp!=null && temp instanceof Number) {counter=temp;}
        System.println("Counter in App initialize: "+counter);        
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        System.println("onStart");   
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    	//moved from onHide() - using the "is this background" trick
    	if(!inBackground) {
	    	var now =System.getClockTime();
    		var ts = now.hour+":"+now.min.format("%02d");        
        	System.println("onStop counter="+counter+" "+ts);    
    		Application.getApp().setProperty(OSCOUNTER, counter);     
    	} else {
    		System.println("onStop");
    	}
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        System.println("getInitialView");
		//register for temporal events if they are supported
    	if(Toybox.System has :ServiceDelegate) {
    		canDoBG = true;
    		Background.registerForTemporalEvent(new Time.Duration(5 * 60));
    	} else {
    		System.println("****background not available on this device****");
    	}
        return [ new watchView() ];
    }


    function onBackgroundData(data) {
        counter++;
        var now = System.getClockTime();
        var ts=now.hour+":"+now.min.format("%02d");
        System.println("onBackgroundData="+data+" "+counter+" at "+ts);
        bgdata = data;
        Application.getApp().setProperty(OSDATA,bgdata);
        WatchUi.requestUpdate();
    }    


    function getServiceDelegate(){
    	var now = System.getClockTime();
    	var ts = now.hour+":"+now.min.format("%02d");    
    	System.println("getServiceDelegate: "+ts);
        return [new watchServiceDelegate()];
    }
    
    function onAppInstall() {
    	System.println("onAppInstall");
    }
    
    function onAppUpdate() {
    	System.println("onAppUpdate");
    }


}

function getApp() as watchApp {
    return Application.getApp() as watchApp;
}