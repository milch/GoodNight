# GoodNight

Based off of Thomas Finch's [GammaThingy][1].

GoodNight is an app that allows you to directly access the screen's gamma
levels, and modify it using `IOMobileFramebuffer`. With this you can do any of
the following:

* Change the screen temperature
* Put the brightness lower than iOS would normally allow you to
* Adjust the RGB values of the framebuffer

This application uses `dlsym`, which loads in the private symbols at runtime,
rather than using headers, so no additional setup is needed once you download
the source.

### Installing

See [here](Help/README.md).

### Compatibility

I am certain that this app will run on any iOS device running iOS 7 or higher.
However, nothing happens when turning on any adjustments if using the iPad Pro.
Unfortunately, I do not currently have one, so it has hard to test and find the
problem. I will do my best to look into it and find a solution.


[1]: https://github.com/thomasfinch/GammaThingy
