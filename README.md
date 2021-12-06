# autoconf & automake wrappers

These are small wrappers that try to select the right tool version depending on
a number of factors:
* Which version is requested via env settings (e.g. WANT_AUTO{CONF,MAKE})
* Which version was used to generate the project files
* If all else fails, try the latest version available
