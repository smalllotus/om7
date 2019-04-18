

OM7 is a new generation of the [OpenMusic](http://repmus.ircam.fr/openmusic/) visual programming and computer-aided composition environment, developed as a research prototype with a number of improvements in terms of graphical interface, computational features and composition.

It is not (yet) intended to replace OM6 and lacks a number of important features (see currentstate/ongoing developments below). External libraries will also need to be ported (at minor cost for most of them). **OM6 is therefore still the official version**, and I am doing my best to keep it running and improving in parallel. The sources are hosted [on this repository](https://github.com/openmusic-project/OM6/) and the latest version can be downloaded [here](https://github.com/openmusic-project/OM6/releases/latest).

## Current state

[OM7 beta 0.1.8](https://github.com/openmusic-project/om7/releases/latest)

  * Visual language is operational, including abstractions, loops, persistence and a lot of new visual programming features.
  * Working conrol objects and editors: BPF, BPC, 3DC, PIANO-ROLL...
  * New maquette/sequencer interface
  * A number of compatible [libraries](Libraries), interfacing with external DSP frameworks (Spat, SuperVP, pM2, Csound...) 
  * Basic score onjects (CHORD, CHORD-SEQ)

### Ongoing developments

  * Rhytmic notation and score objects
  * Compatibility / import patches from OM6

## Some "history"

The om7 project stems from several motivations and origins. Most of the code is written from scratch, but a significant part is largely inspired or borrowed from the original OpenMusic sources and basic musical features, including the indirect contributions of its successive authors and contributors.

The initial objective was to experiment with a number of basic visual and Lisp visual programming functions, without taking into account any specific music application yet.
The first prototype was designed during a visit at the Center for New Music and Audio Technology (CNMAT) at UC Berkeley in 2013.

A second phase started with the [EFFICACe](http://repmus.ircam.fr/efficace/) research project conducted at IRCAM (2013-2017). The objective of this project was to explore the relationships between calculation, time and interactions in computer-assisted music composition processes, focusing on specific topics such as dynamic temporal structures or the control, visualization and interactive execution of sound synthesis and spatialization processes. 
The [reactive model](https://hal.archives-ouvertes.fr/hal-00959312) recently developed in OpenMusic has been integrated as a native feature of om7 visual programs and works seamlessly in the visual programming environment.
Jeremie Gracia created a framework for interactive control and representation of spatial scenes and descriptors, and Dimitri Bouche developed a dynamic scheduling architecture that was implemented and integrated as the main core for musical rendering and computation in om7, as well as new interfaces for temporal representation and organization of compositional processes (a new design of the OpenMusic _maquette_).

At the same time, we have created new editors and architectures for the manipulation of musical objects (curves, temporal data streams, controllers, etc.) that are currently being developed and completed to cover most operational areas of OpenMusic processes.

