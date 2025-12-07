import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Weather;

class robwatchView extends WatchUi.WatchFace {

    var pressureValues = [];

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
    }




    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Get and show the current time
        createClock();
        updateWeather();
        // Call the parent onUpdate function to redraw the layout

        View.onUpdate(dc);
    }

    function updateWeather() as Void {
        var weather = Weather.getCurrentConditions();

        if (weather != null) {
            var lowTemp = weather.lowTemperature.toNumber();
            var temp = weather.temperature.toNumber();
            var highTemp = weather.highTemperature.toNumber();

             var tempString = Lang.format("$1$/$2$ - $3$°", [lowTemp, highTemp, temp]);


            addToView("TemperatureLabel",tempString);
        } else {
            addToView("TemperatureLabel", "-°");
        }
    }


    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
    }


    function createClock() as Void {
        var clockTime = System.getClockTime();
        var timeString = Lang.format("$1$$2$", [clockTime.hour, clockTime.min.format("%02d")]);
        addToView("TimeLabel", timeString);

        var timeMsString = Lang.format("$1$", [clockTime.sec.format("%02d")]);
        addToView("TimeMsLabel", timeMsString);
    }

    function addToView(name, data) as Void {
        var view = View.findDrawableById(name) as Text;
        view.setText(data);
    }




}
