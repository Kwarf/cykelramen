# Cykelramen

This is my first demo, raymarched using [Godot 3.3](https://godotengine.org/)
(a workflow I don't really recommend). It placed 1st at Birdie 31 (2021).

I made the music in FL Studio and bought the Japanese voice samples on Fiverr.

The pun on the word "Cykelramen" probably only works if you know Swedish.

[![YouTube](http://i3.ytimg.com/vi/LPImI5Qw1WA/maxresdefault.jpg)](https://www.youtube.com/watch?v=LPImI5Qw1WA)
*Click the image above to view it on YouTube.*

## Short backstory

My initial intentions was to write my own framework in Rust, and I got
quite far, but wanted to go all-in using crinkler to reduce the size.
However I got stuck on issues when linking my Rust code with WaveSabre
and a C wrapper I made for it, and with just over a week left until Birdie
I decided to scrap that idea and instead took the easy way out and made a
raymarcher directly in Godot.

## License

I've decided to license the music under [CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/)
simply because I don't feel entirely okay with freely sharing music containing
the voice of another person, even though I've paid for it.

All my code however is free to use under [MIT](LICENSE.txt) if someone
is crazy enough to want it, maybe to get into the demoscene using a fairly
simple to use tool. A good place to look in that case would be the `develop`
branch, which still has the UI elements for shader hot-reload and time seeking.

## Attributions

I wouldn't have been able to do this without the
[great raymarching articles by iq](https://www.iquilezles.org/www/index.htm)
as well as the [hg_sdf library](http://mercury.sexy/hg_sdf/) from mercury.

I also recommend [electricsquare/raymarching-workshop](https://github.com/electricsquare/raymarching-workshop)
as a starting point for people like me that have never written a raymarcher
before.
