import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Weather;
import Toybox.Time;
import Toybox.SensorHistory;
import Toybox.Time.Gregorian;
class watchView extends WatchUi.WatchFace {

    var pressureValues = [];

    function initialize() {
        WatchFace.initialize();

        //read last values from the Object Store
        //counter now read in app initialize
        //var temp=App.getApp().getProperty(OSCOUNTER);
        //if(temp!=null && temp instanceof Number) {counter=temp;}
 
        //var temp=App.getApp().getProperty(OSDATA);
        var temp=null;
        if(temp!=null && temp instanceof String) {bgdata=temp;}
        
        var now=System.getClockTime();
    	var ts=now.hour+":"+now.min.format("%02d");
        System.println("From OS: data="+bgdata+" "+counter+" at "+ts);  

    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
         loadResources();
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

    function loadResources() as Void {
    }




    // Update the view
    function onUpdate(dc as Dc) as Void {
        // Get and show the current time
        createClock();
        createWeather();
        createDayMonthDate();
        
        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);

       // setWeatherIcon(dc);

       dc.drawBitmap(-85, 0, WatchUi.loadResource(Rez.Drawables.Skull));

       // Update and draw the barometer graph at the bottom
       updatePressureValues();
       drawBarometer(dc);

    }

    function createWeather() as Void {
        try {
            var weather = Weather.getCurrentConditions();
            var lowTemp = weather.lowTemperature.toNumber();
            var temp = weather.temperature.toNumber();
            var highTemp = weather.highTemperature.toNumber();
            //var tempString = Lang.format("$1$/$2$ - $3$°", [lowTemp, highTemp, temp]);
            var tempFormat = (temp >= 0 ? (temp < 10 ? "0" + temp : temp) : temp) + "°";
            var tempString = Lang.format("$3$", [lowTemp, highTemp, tempFormat]);
            addToView("TemperatureLabel",tempString);

        } catch (ex) {
            addToView("TemperatureLabel", "-°");
        }

    }

    // Pressure sampling: pull last N samples from SensorHistory, populate pressureValues (oldest->newest) and update PressureLabel
    function updatePressureValues() as Void {
        try {
            //System.println("Updating pressure values...");
            pressureValues = [];
            var iter = null;
            if ((Toybox has :SensorHistory) && (SensorHistory has :getPressureHistory)) {

                iter = SensorHistory.getPressureHistory({:period => new Time.Duration(2073600), :order => SensorHistory.ORDER_OLDEST_FIRST});
            }

            if (iter == null) {
                pressureValues = [];
                addToView("PressureLabel", "-");
                return;
            }
            //System.println("Got pressure history iterator.");
            // Collect samples (iterator returns newest first)
            var samples = [];
            var max = iter.getMax();
            var min = iter.getMin();
            var s = iter.next();
            var sampleCount = 0;
            while ((s != null)) {
                if (sampleCount % 2 == 0){
                    sampleCount = sampleCount + 1;
                    s = iter.next();
                }
                //samples.add(s);
                pressureValues.add(s.data / 100.0);

                sampleCount = sampleCount + 1;
                //System.println("Sample " + sampleCount + ": " + s.data);
                s = iter.next();
            }
            //System.println("Total samples: " + sampleCount);
            if (sampleCount == 0) {
                pressureValues = [];
                addToView("PressureLabel", "-");
                return;
            }


          //System.println("Pressure values collected: " + pressureValues.size());
            // Set the label using the newest sample
            if ((max != null) && (min != null)) {
                if (max > 2000) { max = max / 100.0; }
                if (min > 2000) { min = min / 100.0; }
                addToView("PressureLabel", Lang.format("$1$ | $2$", [min.format("%0.0f"), max.format("%0.0f")]));
            } else {
                addToView("PressureLabel", "-");
            }

        } catch (ex) {
            pressureValues = [];
            addToView("PressureLabel", "-");
        }
    }

    function drawBarometer(dc as Dc) as Void {
        //System.println("Drawing barometer graph...");

        // Simple axes: horizontal baseline and left vertical axis
        var graphH = 30;
        var graphW = 90;

        var graphY = 143;
        var graphX = 42;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        // horizontal baseline
        dc.drawLine(graphX, graphY + graphH, graphX + graphW, graphY + graphH);
        // vertical axis (left)
        dc.drawLine(graphX, graphY, graphX, graphY + graphH);

        // Draw line graph (oldest -> newest)
        var points = pressureValues.size();
        if (points <= 0) {
            return;
        }

        // compute min/max
        var minP = pressureValues[0];
        var maxP = minP;
        for (var i = 1; i < points; i++) {
            var v = pressureValues[i];
            if (v < minP) { minP = v; }
            if (v > maxP) { maxP = v; }
        }
        if (minP == maxP) {
            minP = minP - 1;
            maxP = maxP + 1;
        }
        var baselineY = graphY + graphH;

        // Fill area under the curve by drawing vertical lines for each pixel column
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        for (var px = 0; px <= graphW; px++) {
            var x = graphX + px;
            // position in sample space (0..points-1)
            var pos = (points == 1) ? 0 : (px * (points - 1)) / graphW;
            var idx = Math.floor(pos);
            if (idx < 0) { idx = 0; }
            if (idx > points - 1) { idx = points - 1; }
            var frac = pos - idx;
            var v1 = pressureValues[idx];
            var v2 = (idx + 1 < points) ? pressureValues[idx + 1] : v1;
            var val = v1 + (v2 - v1) * frac;
            var y = graphY + graphH - Math.floor((val - minP) * (graphH - 2) / (maxP - minP)) - 1;
            // clamp y
            if (y < graphY) { y = graphY; }
            if (y > baselineY) { y = baselineY; }
            dc.drawLine(x, y, x, baselineY);
        }

        // draw polyline on top of fill
        var stepX = (points == 1) ? 0 : Math.floor(graphW / (points - 1));
        var prevX = graphX;
        var prevY = graphY + graphH - Math.floor((pressureValues[0] - minP) * (graphH - 2) / (maxP - minP)) - 1;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (points == 1) {
            dc.drawLine(prevX, prevY, prevX, prevY);
        } else {
            for (var i = 1; i < points; i++) {
                var x = graphX + i * stepX;
                var val = pressureValues[i];
                var y = graphY + graphH - Math.floor((val - minP) * (graphH - 2) / (maxP - minP)) - 1;
                dc.drawLine(prevX, prevY, x, y);
                prevX = x;
                prevY = y;
            }
        }

    }





    function createClock() as Void {
        var clockTime = System.getClockTime();
        var timeString = Lang.format("$1$$2$", [clockTime.hour, clockTime.min.format("%02d")]);
        addToView("TimeLabel", timeString);

        var timeMsString = Lang.format("$1$", [clockTime.sec.format("%02d")]);
        addToView("TimeMsLabel", timeMsString);
    }

    function createDayMonthDate() as Void {

        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dayString = Lang.format("$1$", [today.day.format("%02d")]);
        addToView("DayLabel", dayString);

        var MonthString = Lang.format("$1$", [today.month.format("%02d")]);
        addToView("MonthLabel", MonthString);
    }



    function addToView(name, data) as Void {
        var view = View.findDrawableById(name) as Text;
        view.setText(data);
    }




    // USE AFTER view.onUpdate(dc);
    function drawCircle(dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.fillCircle(50, 100, 75);
    }

    // USE AFTER view.onUpdate(dc);
    function drawText(dc) as Void {
    var clockTime = System.getClockTime();
    var timeString = Lang.format("$1$$2$", [clockTime.hour, clockTime.min.format("%02d")]);

    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.drawText(
        dc.getWidth() / 2,                      // gets the width of the device and divides by 2
        dc.getHeight() / 2,                     // gets the height of the device and divides by 2
        Graphics.FONT_LARGE,                    // sets the font size
        timeString,                          // the String to display
        Graphics.TEXT_JUSTIFY_CENTER            // sets the justification for the text
                );
    }


    function drawWeatherIcon(dc, icon) as Void {
       dc.drawBitmap(80, 110, icon);
    }


}
