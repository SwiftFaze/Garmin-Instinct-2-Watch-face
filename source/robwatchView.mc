import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Weather;
import Toybox.Time;
import Toybox.SensorHistory;
import Toybox.Time.Gregorian;
class robwatchView extends WatchUi.WatchFace {


    // Declare bitmap variables
    var sunIcon;
    var weatherAlertIcon;
    var windyIcon;
    var snowIcon;
    var lightRainIcon;
    var overcastIcon;
    var clearNightIcon;
    var nightCloudyIcon;
    var stormIcon;
    var fogIcon;
    var cloudyIcon;
    var rainIcon;

    var pressureValues as Array = new Array();

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
         loadResources();
   }

    function loadResources() as Void {
        sunIcon = WatchUi.loadResource(Rez.Drawables.Sun);
        weatherAlertIcon = WatchUi.loadResource(Rez.Drawables.WeatherAlert);
        windyIcon = WatchUi.loadResource(Rez.Drawables.Windy);
        snowIcon = WatchUi.loadResource(Rez.Drawables.Snow);
        lightRainIcon = WatchUi.loadResource(Rez.Drawables.LightRain);
        overcastIcon = WatchUi.loadResource(Rez.Drawables.Overcast);
        clearNightIcon = WatchUi.loadResource(Rez.Drawables.ClearNight);
        nightCloudyIcon = WatchUi.loadResource(Rez.Drawables.NightCloudy);
        stormIcon = WatchUi.loadResource(Rez.Drawables.Storm);
        fogIcon = WatchUi.loadResource(Rez.Drawables.Fog);
        cloudyIcon = WatchUi.loadResource(Rez.Drawables.Cloudy);
        rainIcon = WatchUi.loadResource(Rez.Drawables.Rain);
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
            var iter = null;
            if ((Toybox has :SensorHistory) && (SensorHistory has :getPressureHistory)) {
                iter = SensorHistory.getPressureHistory({:period => new Time.Duration(14400)});
            }
            if (iter == null) {
                pressureValues = [];
                addToView("PressureLabel", "-");
                return;
            }

            // Collect samples (iterator returns newest first)
            var samples = [];
            var newest = null;
            var oldest = null;
            var s = iter.next();
            var sampleCount = 0;
            while ((s != null)) {
                if (sampleCount == 0) { newest = s; }
                samples.add(s);
                sampleCount = sampleCount + 1;
                oldest = s;
                s = iter.next();
            }

            if (sampleCount == 0) {
                pressureValues = [];
                addToView("PressureLabel", "-");
                return;
            }

            // Build pressureValues as oldest -> newest
            
            for (var i = sampleCount - 1; i >= 0; i--) {
                var sample = samples[i];
                if ((sample != null) && (sample.data != null)) {
                    var p = sample.data;
                    if (p > 2000) { // likely in Pa -> convert to hPa
                        p = p / 100.0;
                    }
                    pressureValues.add(p);
                }
            }
          
            // Set the label using the newest sample
            if ((newest != null) && (newest.data != null)) {
                var latestVal = newest.data;
                var oldestVal = oldest.data;
                if (latestVal > 2000) { latestVal = latestVal / 100.0; }
                if (oldestVal > 2000) { oldestVal = oldestVal / 100.0; }
                addToView("PressureLabel", Lang.format("$2$ | $1$", [latestVal.format("%0.0f"), oldestVal.format("%0.0f")]));
            } else {
                addToView("PressureLabel", "-");
            }

        } catch (ex) {
            pressureValues = [];
            addToView("PressureLabel", "-");
        }
    }

    function drawBarometer(dc as Dc) as Void {
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
function setWeatherIcon(dc) as Void {
    var icon = null;
    var weatherText = "";
    var weather = Weather.getCurrentConditions();

    if (weather != null) {
        switch (weather.condition) {
            case Weather.CONDITION_CLEAR:
                icon = sunIcon;
                weatherText = "Clear";
                break;
            case Weather.CONDITION_PARTLY_CLEAR:
                icon = sunIcon;
                weatherText = "Partly Clear";
                break;
            case Weather.CONDITION_MOSTLY_CLEAR:
                icon = sunIcon;
                weatherText = "Mostly Clear";
                break;
            case Weather.CONDITION_FAIR:
                icon = sunIcon;
                weatherText = "Fair";
                break;

            case Weather.CONDITION_PARTLY_CLOUDY:
                icon = cloudyIcon;
                weatherText = "Partly Cloudy";
                break;
            case Weather.CONDITION_MOSTLY_CLOUDY:
                icon = cloudyIcon;
                weatherText = "Mostly Cloudy";
                break;
            case Weather.CONDITION_CLOUDY:
                icon = cloudyIcon;
                weatherText = "Cloudy";
                break;
            case Weather.CONDITION_THIN_CLOUDS:
                icon = cloudyIcon;
                weatherText = "Thin Clouds";
                break;

            case Weather.CONDITION_RAIN:
                icon = rainIcon;
                weatherText = "Rain";
                break;
            case Weather.CONDITION_HEAVY_RAIN:
                icon = rainIcon;
                weatherText = "Heavy Rain";
                break;
            case Weather.CONDITION_LIGHT_RAIN:
                icon = lightRainIcon;
                weatherText = "Light Rain";
                break;
            case Weather.CONDITION_SHOWERS:
                icon = rainIcon;
                weatherText = "Showers";
                break;
            case Weather.CONDITION_HEAVY_SHOWERS:
                icon = rainIcon;
                weatherText = "Heavy Showers";
                break;
            case Weather.CONDITION_LIGHT_SHOWERS:
                icon = lightRainIcon;
                weatherText = "Light Showers";
                break;
            case Weather.CONDITION_DRIZZLE:
                icon = lightRainIcon;
                weatherText = "Drizzle";
                break;
            case Weather.CONDITION_RAIN_SNOW:
                icon = rainIcon;
                weatherText = "Rain/Snow";
                break;
            case Weather.CONDITION_LIGHT_RAIN_SNOW:
                icon = snowIcon;
                weatherText = "Light Rain/Snow";
                break;
            case Weather.CONDITION_HEAVY_RAIN_SNOW:
                icon = snowIcon;
                weatherText = "Heavy Rain/Snow";
                break;

            case Weather.CONDITION_SNOW:
                icon = snowIcon;
                weatherText = "Snow";
                break;
            case Weather.CONDITION_LIGHT_SNOW:
                icon = snowIcon;
                weatherText = "Light Snow";
                break;
            case Weather.CONDITION_HEAVY_SNOW:
                icon = snowIcon;
                weatherText = "Heavy Snow";
                break;
            case Weather.CONDITION_ICE_SNOW:
                icon = snowIcon;
                weatherText = "Ice/Snow";
                break;
            case Weather.CONDITION_FLURRIES:
                icon = snowIcon;
                weatherText = "Flurries";
                break;
            case Weather.CONDITION_CHANCE_OF_SNOW:
                icon = snowIcon;
                weatherText = "Chance of Snow";
                break;
            case Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW:
                icon = snowIcon;
                weatherText = "Cloudy Chance of Snow";
                break;
            case Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW:
                icon = snowIcon;
                weatherText = "Cloudy Chance of Rain/Snow";
                break;

            case Weather.CONDITION_THUNDERSTORMS:
                icon = stormIcon;
                weatherText = "Thunderstorms";
                break;
            case Weather.CONDITION_SCATTERED_THUNDERSTORMS:
                icon = stormIcon;
                weatherText = "Scattered Thunderstorms";
                break;
            case Weather.CONDITION_CHANCE_OF_THUNDERSTORMS:
                icon = stormIcon;
                weatherText = "Chance of Thunderstorms";
                break;

            case Weather.CONDITION_FOG:
                icon = fogIcon;
                weatherText = "Fog";
                break;
            case Weather.CONDITION_HAZY:
                icon = fogIcon;
                weatherText = "Hazy";
                break;
            case Weather.CONDITION_HAZE:
                icon = fogIcon;
                weatherText = "Haze";
                break;
            case Weather.CONDITION_MIST:
                icon = fogIcon;
                weatherText = "Mist";
                break;
            case Weather.CONDITION_DUST:
                icon = fogIcon;
                weatherText = "Dust";
                break;
            case Weather.CONDITION_SMOKE:
                icon = fogIcon;
                weatherText = "Smoke";
                break;
            case Weather.CONDITION_SAND:
                icon = fogIcon;
                weatherText = "Sand";
                break;
            case Weather.CONDITION_VOLCANIC_ASH:
                icon = fogIcon;
                weatherText = "Volcanic Ash";
                break;
            case Weather.CONDITION_SANDSTORM:
                icon = fogIcon;
                weatherText = "Sandstorm";
                break;

            case Weather.CONDITION_WINDY:
                icon = windyIcon;
                weatherText = "Windy";
                break;
            case Weather.CONDITION_SQUALL:
                icon = windyIcon;
                weatherText = "Squall";
                break;
            case Weather.CONDITION_HURRICANE:
                icon = windyIcon;
                weatherText = "Hurricane";
                break;
            case Weather.CONDITION_TROPICAL_STORM:
                icon = windyIcon;
                weatherText = "Tropical Storm";
                break;

            case Weather.CONDITION_HAIL:
                icon = overcastIcon;
                weatherText = "Hail";
                break;
            case Weather.CONDITION_ICE:
                icon = overcastIcon;
                weatherText = "Ice";
                break;
            case Weather.CONDITION_FREEZING_RAIN:
                icon = overcastIcon;
                weatherText = "Freezing Rain";
                break;
            case Weather.CONDITION_SLEET:
                icon = overcastIcon;
                weatherText = "Sleet";
                break;
            case Weather.CONDITION_UNKNOWN_PRECIPITATION:
                icon = overcastIcon;
                weatherText = "Unknown Precipitation";
                break;
            case Weather.CONDITION_UNKNOWN:
                icon = overcastIcon;
                weatherText = "Unknown";
                break;

            default:
                icon = overcastIcon;
                weatherText = "Unknown";
                break;
        }
    }

    // Draw the icon
    if (icon != null) {
        dc.drawBitmap(35, 115, icon);
    }

    // Set the text label
    addToView("WeatherConditionLabel", weatherText);
}



}
