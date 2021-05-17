# Cykelramen

This is my first demo, raymarched using [Godot 3.3](https://godotengine.org/)
(a workflow I don't really recommend). It placed 1st at Birdie 31 (2021).

I made the music in FL Studio and bought the Japanese voice samples on Fiverr.

The pun on the word "Cykelramen" probably only works if you know Swedish.

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

## Prerender

1. Run on a 4k monitor.
2. Use [apitrace/apitrace](https://github.com/apitrace/apitrace)
to save the GL calls to a trace file.
```
apitrace.exe trace cykelramen.exe
```
3. Render images from the trace file.
```
apitrace.exe dump-images cykelramen.trace
```
4. Rename the images so they are sequential (*nnnn.png*), since ffmpeg does not support glob (on Windows?).
5. Merge the images using ffmpeg.
```
ffmpeg.exe -framerate 60 -i %04d.png -c:v libx264 -r 60 -preset slow -crf 18 -pix_fmt yuv420p out.mkv
```
6. Insert the audio (after the precalc loader).
```
ffmpeg.exe -y -i out.mp4 -itsoffset 3.867 -i Cykelramen.wav -map 0:0 -map 1:0 -c:a aac -b:a 256k -c:v copy -preset slow -async 1 outwaudio.mkv
```
