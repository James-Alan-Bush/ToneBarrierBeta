#  ToneBarrier

This is an implementation of a modularized version of ToneBarrier.

It provides a single, universal interface for playback control, allowing for any kind of control (remote events, notifications, user interface, etc.) and multiple controls (lock screen, app window, etc.)

It also provides a single, universal interface for supplying audio data to the components that route sound to hardware.
This allows for variations, improvements, customizations and multiple platform deployments to components that do not necessarily evolve in tandem
or that may require or benefit from flexibility modularization promises. The adaptors between components can be updated or improved without requiring any changes to existing modules.

Following are the modules and interfaces that pertain to playback:
* Playback controls, such as the Play button, Lock Screen controls, interruption handlers, etc., [see ViewController] start/stop playback via ToneGenerator
* ToneGenerator starts/stops playback; the calls made to ToneGenerator will always be the same; the call it makes to the audio engine will always be the same;
the caller and the called have no dependencies
* ToneBarrierPlayer provides a universal interface for connection an audio-data provider (ClicklessTones, etc.) with the audio engine component

Besides providing or accessing functionality through a statically defined interface, all components must provide a universal implementation for
reporting state (such as availability, errors, etc.). The implementation returns a boolean, either TRUE or FALSE, that indicates whether the functionality it provides can be used


** SCRATCH ALL THIS **

A return value should not be necessary; the caller (i.e., the component with functional dependencies on the callee) should provide a block of code to execute depending on the operational status of the callee
 
The connection between caller and callee in this regard is made by the interface; there is no direct calls made between components.

Each implementation related to operational dependencies form a single composition that responds to requests for the operational state as a whole to any
requester  
