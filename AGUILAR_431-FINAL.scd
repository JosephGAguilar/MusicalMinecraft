/* "Musical Mining, powered by OpenAI!" by Joseph Aguilar:
---------------------------------

$ sclang AGUILAR_431-FINAL.scd

*/

(

s.waitForBoot {
	//var for accessing text file with biome information
	var txtPath = thisProcess.nowExecutingPath.dirname +/+ "biome.txt";

	//var for accessing python file with openai access
	var pythonPath = thisProcess.nowExecutingPath.dirname +/+ "openaitest.py";

	//be able to run openai from SuperCollider
	"PATH".setenv("PATH".getenv ++ ":/usr/local/bin");
	"pip3 install openai --user".unixCmd;


	/* --- SynthDefs and other asynchronous stuff ---*/

	//ALL SYNTHDEFS WERE FOUND ONLINE FROM THIS REPOSITORY: https://github.com/SCLOrkHub/SCLOrkSynths/tree/master/SynthDefs
	SynthDef("piano", {
		arg
		//Standard Definitions
		out = 0, freq = 440, amp = 0.1, att = 0.001, rel = 3, pan = 0,
		//Other Controls
		filterRange = 2000, rq = 0.5, harmonic = 2.pow(33.5/12),
		//These Range from 0 to 1
		width = 0.2, mix = 0.7;

		//Electric Piano
		var snd, env, lfo;

		env = Env.perc(att, rel).kr(doneAction: 2); //Original used an ADSR envelope.

		snd = Pulse.ar(
			freq: freq * [1, harmonic], //Original used 33.5.midiratio here, which is just below the 7th harmonic.
			width: [width, width/2],
			mul: [mix, (1 - mix)]
		);
		snd  = BLowPass4.ar(
			in: snd,
			freq: (filterRange * env) + (2 * freq),
			rq: rq
		);
		snd = Mix.ar(snd) * env * amp;

		Out.ar(out, Pan2.ar(snd, pan));
	};
	).add;

	SynthDef(\cheapPiano1, {
		arg
		//Standard values
		out = 0, freq = 440, amp = 0.1, att = 0.001, rel = 1, pan = 0,
		//These range from 0 to 1
		tone = 0.25, hollowness = 0;

		var hammer, snd, delay, tonefreq, env;

		env = Env.perc(att, rel, amp * 4, -1).ar(doneAction: 2);

		// Delay line times: freq, freq - 4 cents, freq + 3 cents. In the original this was done by converting freq to midi.
		delay = (1 / (freq * [2.pow(-0.04/12), 1, 2.pow(0.03/12)]));
		tonefreq = tone.linlin(0, 1, 1000, 5000);

		hammer = Decay2.ar(
			in: Impulse.ar(0.001),
			attackTime: 0.008,
			decayTime: 0.04,
			mul: LFNoise2.ar(freq: amp.linlin(0, 1, tonefreq, 2 * tonefreq), mul: 0.25)
		); //Try LFNoise1, LFNoise0, or even LFClipNoise above for a slightly grainier sound.

		snd = CombL.ar(hammer, delay, delay, 50 * amp);
		snd = HPF.ar(snd, hollowness.linlin(0, 1, 50, 1000));
		snd = snd * env;
		snd = Limiter.ar(snd);
		Out.ar(out, Pan2.ar(snd, pan));
	},
	metadata: (
		credit: "based on something posted 2008-06-17 by jeff, based on an old example by james mcc",
		category: \keyboards,
		tags: [\casio, \piano, \pitched]
	)
	).add;

	SynthDef(\bell, {
		|fs=1, t60=1, pitchy=1, amp=0.25, gate=1|
		var sig, exciter;
		//exciter = Impulse.ar(0);
		exciter = WhiteNoise.ar() * EnvGen.ar(Env.perc(0.001, 0.05), gate) * 0.25;
		sig = Klank.ar(
			`[
				[1, 2, 2.803, 3.871, 5.074, 7.81, 10.948, 14.421],   // freqs
				[1, 0.044, 0.891, 0.0891, 0.794, 0.1, 0.281, 0.079], // amplitudes
				[1, 0.205, 1, 0.196, 0.339, 0.047, 0.058, 0.047]*t60     // ring times
			],
			exciter,
			freqscale:fs*pitchy);
		sig = FreeVerb.ar(sig) * amp;
		DetectSilence.ar(sig, 0.001, 0.5, doneAction:2);
		Out.ar(0, sig!2);
	}).add;

	SynthDef(\flute, {
		| out = 0, freq = 440, amp = 1.0, a = 0.1, r = 0.1|
		//var fmod = 1; // clean
		//var fmod = LFCub.kr(freq:1/12).range(1, LFNoise2.kr(freq:12.0).range(1,1.1)); // tone deaf flute
		var fmod = LFCub.kr(freq:1/12).range(1, LFNoise2.kr(freq:12.0).range(1,1.02)); // flute-like sound
		var env = EnvGen.ar(Env.perc(a, r), levelScale:0.5, doneAction:2);
		var snd = SinOsc.ar(freq * fmod)!2;
		Out.ar(bus:out, channelsArray:(env*(amp*snd).tanh));
	}).add;

	SynthDef(\guitar, {arg out=0, freq=440, pan=0, sustain=0.5, amp=0.3;
		var pluck, period, string;
		pluck = PinkNoise.ar(Decay.kr(Impulse.kr(0.005), 0.05));
		period = freq.reciprocal;
		string = CombL.ar(pluck, period, period, sustain*6);
		string = LeakDC.ar(LPF.ar(Pan2.ar(string, pan), 12000)) * amp;
		DetectSilence.ar(string, doneAction:2);
		Out.ar(out, string)
	}).add;

	SynthDef("steelDrum", {
		arg freq = 440, amp = 0.1, out = 0, pan = 0, att = 0.01, dec = 1.5, curve = -6, filterHarmonic = 6;

		var resFreqArray, resAmpArray, resDecArray, enva, envb, envc, snda, sndb, sndc, snd;

		//Arrays for the bank of resonators, mostly harmonics near 5ths and 9ths, and random amplitudes:
		resFreqArray = [2, 2.98, 4.75, 6.21, 9, 9.15, 11.87];
		resAmpArray = [0.35, 0.23, 0.10, 0.06, 0.07, 0.05, 0.01];
		resDecArray = [0.86, 0.72, 0.37, 0.55, 0.32, 0.21, 0.16];

		//Custom envelope shapes attempting to capture the aparrent "bloom" of a note:
		enva = Env.pairs([[0, 0], [att, 1], [(att + dec), 0]], curve).kr;
		envb = Env.pairs([[0, 0], [(att * 5), 0.25], [(att * 6), 0.75], [((att * 6) + (dec / 2)), 0]], curve).kr;
		envc = Env.pairs([[0, 0], [(att * 5), 0.1], [(att * 8), 0.5], [((att * 8) + (dec / 3)), 0]], curve).kr;

		//Fundamental, octave up, and a bank of enharmonic resonators excited by a metalic sound:
		snda = SinOsc.ar(freq: freq, mul: enva);
		sndb = SinOsc.ar(freq: freq * 2.015, mul: envb);
		sndc = DynKlank.ar(
			specificationsArrayRef:
			Ref.new([
				resFreqArray * freq,
				resAmpArray,
				resDecArray * dec
			]),
			input:
			LPF.ar(HPF.ar(CombN.ar(PinkNoise.ar(1), 1/freq, 1/freq, -1, envc), freq * 2), freq * filterHarmonic)
		);

		//Output stages with a tiny bit of compression to smooth things out:

		snd = Mix.ar([snda, sndb, sndc]) * (amp / 3);
		snd = Limiter.ar(snd, amp);
		DetectSilence.ar(in: snd, amp: 0.0001, time: 0.5, doneAction: 2);
		Out.ar(out, Pan2.ar(snd, pan));

	};
	).add;

	SynthDef(\sax, { |out, freq=440, amp=0.1, gate=1|
		var num = 16;
		var harms = Array.series(num, 1, 1) * Array.exprand(num, 0.995, 1.001);
		var snd = SinOsc.ar(freq * SinOsc.kr(Rand(2.0,5.0),0,Rand(0.001, 0.01),1) * harms, mul:Array.geom(num, 1, 0.63));
		snd = Splay.ar(snd);
		snd = BBandPass.ar(snd, freq * XLine.kr(0.1,4,0.01), 2);
		snd = snd * amp * EnvGen.ar(Env.adsr(0.001, 0.2, 0.7, 0.2), gate, doneAction:2);
		Out.ar(out, snd!2);
	}).add;

	SynthDef(\reed, {
		|out = 0, freq = 440, amp = 0.1, gate = 1, attack = 0.3, release = 0.3|
		var snd, blow;
		// pulse with modulating width
		snd = Pulse.ar((Rand(-0.03, 0.05) + freq.cpsmidi).midicps, 0.48 + LFNoise1.kr(0.06, 0.1), 0.2);
		// add a little "grit" to the reed
		snd = Disintegrator.ar(snd, 0.5, 0.7);
		// a little ebb and flow in volume
		snd = snd * LFNoise2.kr(5, 0.05, 1);
		// use the same signal to control both the resonant freq and the amplitude
		blow = EnvGen.ar(Env.asr(attack, 1.0, release), gate, doneAction: 2);
		snd = snd + BPF.ar(snd, blow.linexp(0, 1, 2000, 2442), 0.3, 3);
		// boost the high end a bit to get a buzzier sound
		snd = BHiShelf.ar(snd, 1200, 1, 3);
		snd = snd * blow;
		Out.ar(out, Pan2.ar(snd, 0, amp));
	}).add;


	s.sync; // waits for asynchronous client-->server communications to complete

	/* --- Pattern classes to play your music --- */

	//a function that takes in a list of biome-specfic arguments and plays a Pdef
	~biomeMusicGenerator = {arg instance, instrument, scale, oct, durs, amp, bellVar = [];
		var event_pbind, mel, dur, len = 8;
		// Randomly generate pitch sequence
		mel = mel.add(Array.fill(len, {oct.choose + scale.choose}));

		//Randomly generate durations
		dur = dur.add(Array.fill(len, {durs.choose}));

		//different variables for a flute
		if (instrument == \flute) {
			Pdef(instance, Pbind('instrument', instrument, 'freq', Pseq(mel[0].midicps), 'dur', Pseq(dur[0]), 'amp', amp, \a, Pkey(\dur)*0.95)).play;
		};

		//different variables for a bell
		if (instrument == \bell){
			Pdef(instance, Pbind('instrument', instrument, 't60', bellVar[0], 'pitchy', bellVar[1], 'fs', Pseq(mel[0].midicps), 'dur', Pseq(dur[0]), 'amp', amp)).play;
		};

		//regular variables for a everything else
		if ((instrument != \flute) && (instrument != \bell)){
			Pdef(instance, Pbind('instrument', instrument, 'freq', Pseq(mel[0].midicps), 'dur', Pseq(dur[0]), 'amp', amp)).play;
		};
	};

	// Event for the Biome Machine
	~biomeMachine = (
		biome: \main_menu, // starting bimoe
		transition: {
			case
			//if paused, lower volume
			{~biomeMachine.in == \pause_menu}
			{
				~ampAll = 0.5;
			}

			//play cheery music when at home, in a village, or on the main menu
			{(~biomeMachine.in == \home) || (~biomeMachine.in == \village) || (~biomeMachine.in == \main_menu)}
			{
				~ampAll = 1.0;

				~in1 = \flute;
				~deg1 = Scale.majorPentatonic.degrees;
				~oct1 = [72];
				~dur1 = [0.5,1,2];
				~amp1 = (0.3 * ~ampAll);
				~bell1 = [];

				~in2 = \guitar;
				~deg2 = Scale.majorPentatonic.degrees;
				~oct2 = [60];
				~dur2 = [0.5,1,2,3];
				~amp2 = (1 * ~ampAll);
				~bell2 = [];

				~in3 = \bell;
				~deg3 = Scale.majorPentatonic.degrees;
				~oct3 = [48];
				~dur3 = [3,2,1,0.5];
				~amp3 = (0.4 * ~ampAll);
				~bell3 = [1, 4];

				~in4 = \piano;
				~deg4 = Scale.majorPentatonic.degrees;
				~oct4 = [60,48,72];
				~dur4 = [2,1,0.5];
				~amp4 = (0.5 * ~ampAll);
				~bell4 = [];
			}

			//play scary chaotic music when facing a mob
			{~biomeMachine.in == \danger}
			{
				~ampAll = 1.0;

				~in1 = \bell;
				~deg1 = Scale.phrygian.degrees;
				~oct1 = [40, 46, 60, 72, 78];
				~dur1 = [1,2];
				~amp1 = (0.1 * ~ampAll);
				~bell1 = [9,1];

				~in2 = \guitar;
				~deg2 = Scale.phrygian.degrees;
				~oct2 = [40, 46, 60, 72, 78];
				~dur2 = [0.25,0.5];
				~amp2 = (0.5 * ~ampAll);
				~bell2 = [];

				~in3 = \piano;
				~deg3 = Scale.phrygian.degrees;
				~oct3 = [40, 46, 60, 72, 78];
				~dur3 = [1, 2];
				~amp3 = (0.5 * ~ampAll);
				~bell3 = [];

				~in4 = \reed;
				~deg4 = Scale.phrygian.degrees;
				~oct4 = [40, 46, 60, 72, 78];
				~dur4 = [0.25,0.1];
				~amp4 = (0.5 * ~ampAll);
				~bell4 = [];
			}

			//play somber/mysterious adventuring music when in a forest/plains/jungle biome
			{(~biomeMachine.in == \forest) || (~biomeMachine.in == \plains) || (~biomeMachine.in == \jungle)}
			{
				~ampAll = 1.0;

				~in1 = \flute;
				~deg1 = Scale.minorPentatonic.degrees;
				~oct1 = [72];
				~dur1 = [0.5,1,2,3];
				~amp1 = (0.3 * ~ampAll);
				~bell1 = [];

				~in2 = \flute;
				~deg2 = Scale.minorPentatonic.degrees;
				~oct2 = [60];
				~dur2 = [0.5,1,2,3];
				~amp2 = (0.3 * ~ampAll);
				~bell2 = [];

				~in3 = \guitar;
				~deg3 = Scale.minorPentatonic.degrees;
				~oct3 = [60];
				~dur3 = [2,1,0.5];
				~amp3 = (0.5 * ~ampAll);
				~bell3 = [];

				~in4 = \piano;
				~deg4 = Scale.minorPentatonic.degrees;
				~oct4 = [60,48,72];
				~dur4 = [0.75, 2,1,0.5];
				~amp4 = (0.5 * ~ampAll);
				~bell4 = [];
			}

			//play eerie bells in a cave
			{~biomeMachine.in == \cave}
			{
				~ampAll = 1.0;

				~in1 = \bell;
				~deg1 = Scale.locrian.degrees;
				~oct1 = [40, 46, 60, 72, 78];
				~dur1 = [4,3,2,1,5];
				~amp1 = (0.25 * ~ampAll);
				~bell1 = [9, 1];

				~amp2 = 0;
				~amp3 = 0;
				~amp4 = 0;
			}

			//play twinkling bells in snow
			{~biomeMachine.in == \snow}
			{
				~ampAll = 1.0;

				~in1 = \bell;
				~deg1 = Scale.majorPentatonic.degrees;
				~oct1 = [48];
				~dur1 = [2,1,0.5,0.25];
				~amp1 = (0.25 * ~ampAll);
				~bell1 = [1,4];

				~in2 = \bell;
				~deg2 = Scale.majorPentatonic.degrees;
				~oct2 = [48];
				~dur2 = [0.5,1,2,3];
				~amp2 = (0.15 * ~ampAll);
				~bell2 = [6,4];

				~in3 = \piano;
				~deg3 = Scale.majorPentatonic.degrees;
				~oct3 = [72];
				~dur3 = [2,1,0.5,0.25];
				~amp3 = (0.1 * ~ampAll);
				~bell3 = [];

				~amp4 = 0;
			}

			//play dire guitar and wavy piano in desert
			{~biomeMachine.in == \desert}
			{
				~ampAll = 1.0;

				~in1 = \guitar;
				~deg1 = Scale.enigmatic.degrees;
				~oct1 = [72];
				~dur1 = [2,1,3];
				~amp1 = (0.75 * ~ampAll);
				~bell1 = [];

				~in2 = \guitar;
				~deg2 = Scale.enigmatic.degrees;
				~oct2 = [48,60];
				~dur2 = [1,2,3];
				~amp2 = (0.75 * ~ampAll);
				~bell2 = [];

				~in3 = \cheapPiano1;
				~deg3 = Scale.enigmatic.degrees;
				~oct3 = [48];
				~dur3 = [2,1,0.5,0.25];
				~amp3 = (0.25 * ~ampAll);
				~bell3 = [];

				~amp4 = 0;
			}

			//tropical steel drums and guitar and synth piano on the beach
			{(~biomeMachine.in == \beach) || (~biomeMachine.in == \ocean)}
			{
				~ampAll = 1.0;

				~in1 = \steelDrum;
				~deg1 = Scale.majorPentatonic.degrees;
				~oct1 = [72,60];
				~dur1 = [0.5,1,0.75];
				~amp1 = (1.0 * ~ampAll);
				~bell1 = [];

				~in2 = \guitar;
				~deg2 = Scale.majorPentatonic.degrees;
				~oct2 = [60];
				~dur2 = [0.5,1,2,3];
				~amp2 = (0.75 * ~ampAll);
				~bell2 = [];

				~in3 = \guitar;
				~deg3 = Scale.majorPentatonic.degrees;
				~oct3 = [60];
				~dur3 = [3,2,1,0.5];
				~amp3 = (0.75 * ~ampAll);
				~bell3 = [];

				~in4 = \cheapPiano1;
				~deg4 = Scale.majorPentatonic.degrees;
				~oct4 = [60,48];
				~dur4 = [2,1,0.5,0.25];
				~amp4 = (0.25 * ~ampAll);
				~bell4 = [];
			}

			//weird saxophone in a swamp
			{~biomeMachine.in == \swamp}
			{
				~ampAll = 1.0;

				~in1 = \guitar;
				~deg1 = Scale.minorPentatonic.degrees;
				~oct1 = [60];
				~dur1 = [1,3,2];
				~amp1 = (0.75 * ~ampAll);
				~bell1 = [];

				~in2 = \sax;
				~deg2 = Scale.minorPentatonic.degrees;
				~oct2 = [48, 60];
				~dur2 = [1,2,3];
				~amp2 = (0.75 * ~ampAll);
				~bell2 = [];

				~in3 = \sax;
				~deg3 = Scale.minorPentatonic.degrees;
				~oct3 = [48, 60];
				~dur3 = [1,2,0.5];
				~amp3 = (0.75 * ~ampAll);
				~bell3 = [];

				~in4 = \cheapPiano1;
				~deg4 = Scale.minorPentatonic.degrees;
				~oct4 = [48];
				~dur4 = [2,1,0.5,0.25];
				~amp4 = (0.25 * ~ampAll);
				~bell4 = [];
			}

			{ "Biome doesn't exist *shrug*".warn;} };
	);

	~biomeMachine.transition(~biomeMachine.in = \main_menu);

	//play four different parts that change based on the biome.
	fork {loop {
		~biome = FileReader.read(txtPath)[0][0].asSymbol;
		~biomeMachine.transition(~biomeMachine.in = ~biome);
		if (Pdef(\in1).isActive.not)
		{
			~biomeMusicGenerator.value(\in1, ~in1, ~deg1, ~oct1, ~dur1, ~amp1, ~bell1);
		};

		if (Pdef(\in2).isActive.not)
		{
			~biomeMusicGenerator.value(\in2, ~in2, ~deg2, ~oct2, ~dur2, ~amp2, ~bell2);
		};

		if (Pdef(\in3).isActive.not)
		{
			~biomeMusicGenerator.value(\in3, ~in3, ~deg3, ~oct3, ~dur3, ~amp3, ~bell3);
		};

		if (Pdef(\in4).isActive.not)
		{
			~biomeMusicGenerator.value(\in4, ~in4, ~deg4, ~oct4, ~dur4, ~amp4, ~bell4);
		};

		//check if the biome has changed every two seconds. check if any of the parts have finished playing and start playing again.
		2.0.wait;
	}
	};

	//check every 10 seconds which biome the player is in
	fork {loop {
		("python3 " ++ pythonPath ++ " --user").unixCmd;
		10.0.wait;
	};
	};

}
)