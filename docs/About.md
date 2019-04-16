

OM7 is a new generation of the [OpenMusic](http://repmus.ircam.fr/openmusic/) visual programming and computer-aided composition environment, developed as a research protoytype including a number of improvements in terms of graphical interface, computational possibilities, and compositional affordance in general. 

It is not yet meant to replace OpenMusic and lacks a number of important features to do so. Patch files are not compatible, and most musical objects and libraries still need to be ported – hence the (m). OM6 is the official version, and I'm doing my best to keep it working and improved in parallel.
The sources are hosted [on the this repository](https://github.com/openmusic-project/OM6/) and the latest version can be downloaded for free [from Ircam ForumNet](http://forumnet.ircam.fr/shop/fr/forumnet/43-openmusic.html).


## Some "history"

The om7 project stems from several motivations and origins. Most of the code is being written from scratch, but a significant part of it is significantly inspired, or even borrows portions from the original OpenMusic sources and basic musical functionality, therefore including the indirect contributions of its successive authors and contributors.

The initial objective was to experiment with a number of basic visual programming features and visual Lisp programming, not yet taking into consideration any musical-specific application.
The first prototype was drafted during a vist at the Center for New Music and Audio Technology at UC Berkeley in 2013.

A second stage started along with the [EFFICACe](http://repmus.ircam.fr/efficace/) research project carried out at IRCAM (2013-2017). The objective of this project was to explore the relations between computation, time and interactions in computer-aided music composition processes, with a focus on more specific topics such as dynamic time structures or the interactive control, visualisation and execution of sound synthesis and spatialization processes.
The recent [reactive framework](https://hal.archives-ouvertes.fr/hal-00959312) developed in OpenMusic has been integrated as a native feature of om7 visual programs and seamlessly runs in the visual programming environment. 
[Jeremie Gracia](http://jeremiegarcia.fr/) created a framework for the interactive control and representation of spatial scenes and descriptors, and [Dimitri Bouche](http://repmus.ircam.fr/bouche) developed a dynamic scheduling architecture that has been implemented and integrated as the main kernel for musical rendering and computation in om7, along with new interfaces for the temporal representation and organisation of compositional processes (a renewed conception of the OpenMusic concept of _maquette_).

In the meantime we developed new editors and architectures for the manipulation of musical objects (curves, data streams, controllers etc.) which are currently being worked out and completed with the objective to cover most of the operative realm of OpenMusic processes.



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

