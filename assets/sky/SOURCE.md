# Space skybox source

Author: kurtk84; submitted by Calinou, 2014-11-23.
Source: https://opengameart.org/content/space-skybox-1
Download: https://opengameart.org/sites/default/files/kurt.zip
Retrieved: 2026-09-14.
The source listing licenses the pack as CC0:
https://creativecommons.org/publicdomain/zero/1.0/
The archive also contains the WTFPL v2 text retained unchanged as `space.txt`.

Archive SHA-256:
`dbb43d038c3c0646b2e710e7a045c836a38afea50e39111bf816f6eab87d9abd`

The six 1024x1024 PNG faces are unchanged. They are assembled into a runtime
cubemap with quarter-turns on the top/bottom faces to match the cube sampler;
the authored sky shader adds exposure and a separate warm sun disc/glare.
