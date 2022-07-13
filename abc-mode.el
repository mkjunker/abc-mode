;;; abc-mode.el --- Major mode for editing abc music files

;; Copyright (C) 2002, 2003, 2004, 2006, 2008, 2012, 2013, 2014, 2017,
;; 2021, 2022 Matthew K. Junker

;; Author: Matthew K. Junker <junker@alum.mit.edu>
;; Package-Version: 20220711.1356
;; Keywords: local, docs

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:
;;
;; A major mode for editing abc music files.  Includes some abc2midi
;; features.
;;

;; Written for Emacs version 21.  May or may not work with previous
;; versions.

;; See the Common Customizations section below.  Or run
;; `abc-customize'.

;; This package is stored at https://github.com/mkjunker/abc-mode.

;;; History:
;; 03/29/02 Added customization.
;; 04/03/02 Fixed some of the customizations.
;; 06/10/02 Corrected abc-font-lock-keywords (thank you Atte Andre
;;          Jensen)
;; 06/27/02 Fixed highlighting of !! pairs.
;;          Upgraded for abcm2ps 2.11.  -A, and -o removed.  Changed
;;          default program name to abcm2ps.
;; 07/26/02 Added menus and more customization.
;; 07/29/02 Added abcpp features (thank you Starling).
;; 07/30/02 Made the search expression for titles customizable.
;; 07/31/02 Tried to make the key map more understandable.
;; 09/12/02 Added easier ways of setting preprocessor options.
;;          Corrected the preprocessor command line.
;; 09/17/02 Added prefix argument for setting preprocessor options.
;; 10/08/02 Added mouse input for notes and other symbols.
;; 10/18/02 Added space after %%staves in the skeleton
;; 12/02/02 Added some mouse input symbols.

;;; Code:

(require 'easymenu)
(require 'newcomment)
(require 'autoinsert)
(require 'align)

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.abp\\'"  . abc-mode))
;;;###autoload
(add-to-list 'auto-mode-alist '("\\.abc\\'"  . abc-mode))
;;;###autoload
(when (require 'autoinsert nil t)
  (add-to-list 'auto-insert-alist '(abc-mode . abc-skeleton)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defgroup abc-mode nil
  "Major mode for editing and processing `abc' music files."
  :group 'local)

(defcustom abc-mode-hook nil
  "*Hook called by `abc-mode'."
  :type 'hook
  :group 'abc-mode)

(defcustom abc-mode-comment-start "%" "*Comment string to use in abc mode."
  :type 'regexp :group 'abc-mode)

(defcustom abc-default-meter "4/4" "*Default meter to insert in new songs."
  :type 'string :group 'abc-mode)
(defcustom abc-default-length "1/4"
  "*Default note length to insert in new songs."
  :type 'string :group 'abc-mode)
(defcustom abc-default-tempo "1/4=120" "*Default tempo to insert in new songs."
  :type 'string :group 'abc-mode)
(defcustom abc-default-key "C" "*Default key to insert in new songs."
  :type 'string :group 'abc-mode)

(defcustom abc-song-number-regexp
  "^[ \t]*X[ \t]*:[ \t]*\\([0-9]+\\)"
  "*Regular expression for finding song numbers."
  :type 'regexp
  :group 'abc-mode)

(defcustom abc-use-song-as-page-delimiter
  t
  "*If non-nil, use `abc-song-number-regexp' as the `page-delimiter'.
This feature takes effect when `abc-mode' is executed."
  :type 'boolean
  :group 'abc-mode)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defgroup abc-abc2ps nil "Items related to `abc2ps'." :group 'abc-mode)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defcustom abc-executable "abcm2ps" "*Name of the abc2ps executable."
  :type 'string :group 'abc-abc2ps)

;;; abcm2ps options come in 2 flavors.  Common sets are chosen from
;;; those listed in `abc-option-alist'.  These are intended for every
;;; day use.  `abc-additional-options' are intended for use in a
;;; session.  If you find yourself using this variable a lot with the
;;; same values, you should add to `abc-option-alist'.

(defcustom abc-preferred-options ""
  "*Preferred option set for abc2ps.
See `abc-option-alist'."
  :type 'string :group 'abc-abc2ps)

(defcustom abc-option-alist
  (list (cons "pretty" "-p")
        (cons "pretty2" "-P")
        (cons "fbook" "-F fbook.fmt")
        (cons "landscape" "-F landscape.fmt")
        (cons "tight" "-F tight.fmt")
        (cons "none" ""))
        ;; add homegrown formats by customizing or with add-to-list
  "*List of option sets available to `abc-set-abc2ps-option-set'.
A list of pairs of the format (NAME-STRING OPTION-STRING)."
  :type '(alist :key-type string :value-type string) :group 'abc-abc2ps)

(defcustom abc-additional-options ""
  "*Program flags beyond those from the option sets."
  :type 'string :group 'abc-abc2ps)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defgroup abc-abc2midi nil "Items related to `abc2midi'." :group 'abc-mode)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defcustom abc-midi-executable "abc2midi" "*Name of the abc2midi executable."
  :type 'string :group 'abc-abc2midi)

(defcustom abc-midi-chord-list
  (concat
   "% additional\n"
   "%%MIDI chordname °      0 3 6 9\n"
   "%%MIDI chordname sus2   0 2 7\n"
   "%%MIDI chordname sus4   0 5 7\n"
   "%%MIDI chordname msus   0 3 5 7\n"
   "%%MIDI chordname 6-5    0 4 6 9\n"
   "%%MIDI chordname 6-9    0 4 6 9 13\n"
   "%%MIDI chordname m7-5   0 3 6 10\n"
   "%%MIDI chordname 7+     0 4 8 10\n"
   "%%MIDI chordname 7sus   0 4 5 7 10\n"
   "%%MIDI chordname 7-5    0 4 6 10\n"
   "%%MIDI chordname 9+     0 4 8 10 14\n"
   "%%MIDI chordname 13-9   0 4 7 10 13 21\n")
  "*List of common chords for abc2midi."
  :type 'string
  :group 'abc-abc2midi)

(defcustom abc-midi-default-chord-list
  (concat
   "% Default chords\n"
   "%%MIDI chordname Maj    0 4 7\n"
   "%%MIDI chordname m      0 3 7\n"
   "%%MIDI chordname 7      0 4 7 10\n"
   "%%MIDI chordname m7     0 3 7 10\n"
   "%%MIDI chordname maj7   0 4 7 11\n"
   "%%MIDI chordname M7     0 4 7 11\n"
   "%%MIDI chordname 6      0 4 7 9\n"
   "%%MIDI chordname m6     0 3 7 9\n"
   "%%MIDI chordname aug    0 4 8\n"
   "%%MIDI chordname +      0 4 8\n"
   "%%MIDI chordname aug7   0 4 8 10\n"
   "%%MIDI chordname dim    0 3 6\n"
   "%%MIDI chordname dim7   0 3 6 9\n"
   "%%MIDI chordname 9      0 4 7 10 2\n"
   "%%MIDI chordname m9     0 3 7 10 2\n"
   "%%MIDI chordname maj9   0 4 7 11 2\n"
   "%%MIDI chordname M9     0 4 7 11 2\n"
   "%%MIDI chordname 11     0 4 7 10 2 5\n"
   "%%MIDI chordname dim9   0 4 7 10 13\n"
   "%%MIDI chordname sus    0 5 7\n"
   "%%MIDI chordname sus9   0 2 7\n"
   "%%MIDI chordname 7sus4  0 5 7 10\n"
   "%%MIDI chordname 7sus9  0 2 7 10\n"
   "%%MIDI chordname 5      0 7\n")
  "*List of default chords for abc2midi.  Provided for portability of files.
This list is intended to match the built-in chords provided by abc2midi."
  :type 'string
  :group 'abc-abc2midi)


(defcustom abc-midi-instruments-alist
  (list
   (cons "Acoustic Grand Piano"                  0)
   (cons "Bright Acoustic Piano"                 1)
   (cons "Electric Grand Piano"                  2)
   (cons "Honky-tonk Piano"                      3)
   (cons "Electric Piano 1"                      4)
   (cons "Electric Piano 2"                      5)
   (cons "Harpsichord"                           6)
   (cons "Clavi"                                 7)
   (cons "Celesta"                               8)
   (cons "Glockenspiel"                          9)
   (cons "Music Box"                             10)
   (cons "Vibraphone"                            11)
   (cons "Marimba"                               12)
   (cons "Xylophone"                             13)
   (cons "Tubular Bells"                         14)
   (cons "Dulcimer"                              15)
   (cons "Drawbar Organ"                         16)
   (cons "Percussive Organ"                      17)
   (cons "Rock Organ"                            18)
   (cons "Church Organ"                          19)
   (cons "Reed Organ"                            20)
   (cons "Accordion"                             21)
   (cons "Harmonica"                             22)
   (cons "Tango Accordion"                       23)
   (cons "Acoustic Guitar (nylon)"               24)
   (cons "Acoustic Guitar (steel)"               25)
   (cons "Electric Guitar (jazz)"                26)
   (cons "Electric Guitar (clean)"               27)
   (cons "Electric Guitar (muted)"               28)
   (cons "Overdriven Guitar"                     29)
   (cons "Distortion Guitar"                     30)
   (cons "Guitar harmonics"                      31)
   (cons "Acoustic Bass"                         32)
   (cons "Electric Bass (finger)"                33)
   (cons "Electric Bass (pick)"                  34)
   (cons "Fretless Bass"                         35)
   (cons "Slap Bass 1"                           36)
   (cons "Slap Bass 2"                           37)
   (cons "Synth Bass 1"                          38)
   (cons "Synth Bass 2"                          39)
   (cons "Violin"                                40)
   (cons "Viola"                                 41)
   (cons "Cello"                                 42)
   (cons "Contrabass"                            43)
   (cons "Tremolo Strings"                       44)
   (cons "Pizzicato Strings"                     45)
   (cons "Orchestral Harp"                       46)
   (cons "Timpani"                               47)
   (cons "String Ensemble 1"                     48)
   (cons "String Ensemble 2"                     49)
   (cons "SynthStrings 1"                        50)
   (cons "SynthStrings 2"                        51)
   (cons "Choir Aahs"                            52)
   (cons "Voice Oohs"                            53)
   (cons "Synth Voice"                           54)
   (cons "Orchestra Hit"                         55)
   (cons "Trumpet"                               56)
   (cons "Trombone"                              57)
   (cons "Tuba"                                  58)
   (cons "Muted Trumpet"                         59)
   (cons "French Horn"                           60)
   (cons "Brass Section"                         61)
   (cons "SynthBrass 1"                          62)
   (cons "SynthBrass 2"                          63)
   (cons "Soprano Sax"                           64)
   (cons "Alto Sax"                              65)
   (cons "Tenor Sax"                             66)
   (cons "Baritone Sax"                          67)
   (cons "Oboe"                                  68)
   (cons "English Horn"                          69)
   (cons "Bassoon"                               70)
   (cons "Clarinet"                              71)
   (cons "Piccolo"                               72)
   (cons "Flute"                                 73)
   (cons "Recorder"                              74)
   (cons "Pan Flute"                             75)
   (cons "Blown Bottle"                          76)
   (cons "Shakuhachi"                            77)
   (cons "Whistle"                               78)
   (cons "Ocarina"                               79)
   (cons "Lead 1 (square)"                       80)
   (cons "Lead 2 (sawtooth)"                     81)
   (cons "Lead 3 (calliope)"                     82)
   (cons "Lead 4 (chiff)"                        83)
   (cons "Lead 5 (charang)"                      84)
   (cons "Lead 6 (voice)"                        85)
   (cons "Lead 7 (fifths)"                       86)
   (cons "Lead 8 (bass + lead)"                  87)
   (cons "Pad 1 (new age)"                       88)
   (cons "Pad 2 (warm)"                          89)
   (cons "Pad 3 (polysynth)"                     90)
   (cons "Pad 4 (choir)"                         91)
   (cons "Pad 5 (bowed)"                         92)
   (cons "Pad 6 (metallic)"                      93)
   (cons "Pad 7 (halo)"                          94)
   (cons "Pad 8 (sweep)"                         95)
   (cons "FX 1 (rain)"                           96)
   (cons "FX 2 (soundtrack)"                     97)
   (cons "FX 3 (crystal)"                        98)
   (cons "FX 4 (atmosphere)"                     99)
   (cons "FX 5 (brightness)"                     100)
   (cons "FX 6 (goblins)"                        101)
   (cons "FX 7 (echoes)"                         102)
   (cons "FX 8 (sci-fi)"                         103)
   (cons "Sitar"                                 104)
   (cons "Banjo"                                 105)
   (cons "Shamisen"                              106)
   (cons "Koto"                                  107)
   (cons "Kalimba"                               108)
   (cons "Bag pipe"                              109)
   (cons "Fiddle"                                110)
   (cons "Shanai"                                111)
   (cons "Tinkle Bell"                           112)
   (cons "Agogo"                                 113)
   (cons "Steel Drums"                           114)
   (cons "Woodblock"                             115)
   (cons "Taiko Drum"                            116)
   (cons "Melodic Tom"                           117)
   (cons "Synth Drum"                            118)
   (cons "Reverse Cymbal"                        119)
   (cons "Guitar Fret Noise"                     120)
   (cons "Breath Noise"                          121)
   (cons "Seashore"                              122)
   (cons "Bird Tweet"                            123)
   (cons "Telephone Ring"                        124)
   (cons "Helicopter"                            125)
   (cons "Applause"                              126)
   (cons "Gunshot"                               127)
   ;; aliases
   (cons "piano"                                 0)
   (cons "piano, acoustic grand"                 0)
   (cons "piano, bright acoustic"                1)
   (cons "piano, electric grand"                 2)
   (cons "piano, honky-tonk"                     3)
   (cons "piano, electric 1"                     4)
   (cons "piano, electric 2"                     5)
   (cons "organ"                                 19)
   (cons "organ, drawbar"                        16)
   (cons "organ, percussive"                     17)
   (cons "organ, rock"                           18)
   (cons "organ, church"                         19)
   (cons "organ, reed"                           20)
   (cons "accordion, tango"                      23)
   (cons "guitar"                                24)
   (cons "guitar, acoustic (nylon)"              24)
   (cons "guitar, acoustic (steel)"              25)
   (cons "steel guitar"                          25)
   (cons "guitar, electric (jazz)"               26)
   (cons "guitar, electric (clean)"              27)
   (cons "guitar, electric (muted)"              28)
   (cons "guitar, overdriven"                    29)
   (cons "guitar, distortion"                    30)
   (cons "bass"                                  32)
   (cons "bass, acoustic"                        31)
   (cons "bass, electric (finger)"               33)
   (cons "bass, electric (pick)"                 34)
   (cons "bass, fretless"                        35)
   (cons "bass, slap 1"                          36)
   (cons "bass, slap 2"                          37)
   (cons "bass, synth 1"                         38)
   (cons "bass, synth 2"                         39)
   (cons "trumpet, muted"                        59)
   (cons "sax, soprano"                          64)
   (cons "sax, alto"                             65)
   (cons "sax, tenor"                            66)
   (cons "sax, baritone"                         67))
  "*List of MIDI instrument codes.

Note that in previous versions these numbers were 1 greater.
From the documentation of abc2midi:

Abc2midi: Some of the documentation which comes with abc2midi
states that the MIDI program number should range between 1 and
128; however, as far back as 2003, abc2midi expects the range to
be between 0 and 127 following the MIDI standard. The
documentation abcguide.txt and the man page abc2midi.1 have been
corrected.  Unfortunately, the Abc standard was based on the old
documentation.  It is too late to change abc2midi to comply with
the abc standard since there are too many abc existing files
using the current convention. As a temporary compromise, I have
added a new command %%MIDI programbase.

The current default is (so you do not need this line).
%%MIDI programbase 0

To change to the abc standard use
%%MIDI programbase 1"
  :type '(alist :key-type string :value-type number)
  :group 'abc-abc2midi)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defgroup abc-abc2abc nil "Items related to `abc2abc'." :group 'abc-mode)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom abc-abc2abc-executable "abc2abc" "*Name of the abc2abc executable."
  :type 'string :group 'abc-abc2abc)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defgroup abc-preprocessor nil "Items related to `abcpp'." :group 'abc-mode)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defcustom abc-pp-executable nil
  "*Name of the preprocessor.  Nil for no preprocessing."
  :type '(choice string (const nil))
  :group 'abc-preprocessor)

(defcustom abc-pp-options "" "*Flags for the preprocessor."
  :type 'string :group 'abc-preprocessor)

(defcustom abc-pp-midi-macro "-MIDI"
"*Preprocessor macro for MIDI files.
This string is automatically inserted on the preprocessor command line
when MIDI output is desired."
  :type 'string :group 'abc-preprocessor)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defgroup abc-mode-tags nil "Field tags for `abc' music files."
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  :group 'abc-mode)

(defcustom abc-title-regexp "^T:"
  "*Field tag for titles.  Used by `abc-list-buffer-songs'.

Modify this if you use a preprocessor or you want to list something
besides titles."
  :type 'string
  :group 'abc-mode-tags)

(defcustom abc-reference-tag "X:" "*Reference number tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-title-tag "T:" "*Title tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-composer-tag "C:" "*Composer tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-lyricist-tag "A:" "*Lyricist tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-meter-tag "M:" "*Meter tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-length-tag "L:" "*Unit note length tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-tempo-tag "Q:" "*Tempo tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-parts-tag "P:" "*Parts tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-staves-tag "%%staves" "*Staves tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-key-tag "K:" "*Key tag."
  :type 'string :group 'abc-mode-tags)

(defcustom abc-area-tag "A:" "*Area tag (deprecated)."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-book-tag "B:" "*Book tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-discography-tag "D:" "*Discography tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-filename-tag "F:" "*File Name tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-group-tag "G:" "*Group tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-history-tag "H:" "*History tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-information-tag "I:" "*Information tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-notes-tag "N:" "*Notes tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-origin-tag "O:" "*Origin tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-rhythm-tag "R:" "*Rhythm tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-source-tag "S:" "*Source tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-user-tag "U:" "*User Defined tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-words-end-tag "W:" "*Words (at End) tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-words-tag "w:" "*Words (Internal) tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-transcription-tag "Z:" "*Transcription note tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-version-tag "%%abc-version " "*Version extended information tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-copyright-tag "%%abc-copyright "
  "*Copyright extended information tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-creator-tag "%%abc-creator " "*Creator extended information tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-charset-tag "%%abc-charset " "*Charset extended information tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-include-tag "%%abc-include " "*Include extended information tag."
  :type 'string :group 'abc-mode-tags)
(defcustom abc-edited-by-tag "%%abc-edited-by " "*Edited by tag."
  :type 'string :group 'abc-mode-tags)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defgroup abc-mouse nil "Mouse input for abc mode." :group 'abc-mode)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defcustom abc-mouse-pad
  "\"                     -- E --    -- c' --  !crescendo(! !crescendo)!
6               ^ _ =   D          b       !diminuendo(! !diminuendo)!
7                   -- C --    -- a --
9                     B,         g         space %
11  ---------------- A, ------- f -------- newline
13      ( [  ^ = _  G,         e  ] ) | :  undo <-
m   -------------- F, -- z -- d ---------- , '
maj        H      E,         c  /  2 3/2 >
dim ------------ D, -- x -- B ------------ !pppp! !ppp! !pp! !p! !mp!
#          .    C,         A    /4 4 3/4 < !mf! !f! !ff! !fff! !ffff! !sfz!
b   ---------- B,, - Z -- G --------------
           L  A,,        F      /8 8 3/8   !accent! !fermata! !emphasis!
    -------- G,, ------ E ---------------- !breath! !shortphrase! !mediumphrase!
            F,,        D    V: 1 2 3 4 5   !longphrase!
        -- E,, --  -- C --     6 7 8 9     !segno! !coda! !D.S.! !D.C.!
          D,,        B,                    !fine!
      -- C,, --  -- A, --\n"
  "*Array of symbols for mouse entry."
  :type 'string :group 'abc-mouse)

(defcustom abc-mouse-specials
  (list (cons "<-"      (function (lambda () (delete-char -1))))
        (cons "space"   (function (lambda () (insert " "))))
        (cons "newline" (function (lambda () (insert "\n"))))
        (cons "undo"    (function (lambda () (advertised-undo)))))
  "*Alist of mouse buffer (`abc-mouse-pad') text and desired actions."
  :type '(alist :key-type string :value-type function) :group 'abc-mouse)


(defvar abc-option-history nil "History of option sets.")
(defvar abc-additional-option-history nil "History of additional options.")
(defvar abc-instrument-history nil "History of MIDI instruments.")

(defun abc-set-abc2ps-option-set ()
  "Set options for running abc2ps.

Choose the preferred option set from `abc-option-alist' and set any
additional options."
  (interactive)
  (setq abc-preferred-options
        (cdr
         (assoc
          (completing-read "Option set to use: "
                           abc-option-alist nil t nil
                           'abc-option-history "none")
          abc-option-alist)))
  (setq abc-additional-options
        (read-from-minibuffer "Additional options: " nil nil nil nil
                              'abc-additional-option-history)))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Syntax & font-lock
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar abc-mode-syntax-table nil "Syntax table used while in abc mode.")
(if abc-mode-syntax-table
    ()
  (setq abc-mode-syntax-table (make-syntax-table))
  (modify-syntax-entry ?%  "<" abc-mode-syntax-table)
  (modify-syntax-entry ?\n ">" abc-mode-syntax-table))

(require 'cus-face)
(defvar abc-font-lock-keywords
  (list
   '("^[ \t]*[A-JL-SUX-Z][ \t]*:[^%\n]*" 0 'font-lock-keyword-face t)
   '("^[ \t]*T[ \t]*:[^%\n]*"         0 'secondary-selection t)
   '("^[ \t]*[KV][ \t]*:[^%\n]*"      0 'bold t)
   '("^[ \t]*%%[^\n%]*"               0 'font-lock-constant-face t)
   '("^[ \t]*%%[ \t]*MIDI[^%\n]*"     0 'fringe t)
   '("![^!\n]*!"                      0 'fringe t)
   '("^[ \t]*[Ww]:[^\n%]*"            0 'font-lock-type-face t)
   ;; allows weird combinations, but they are illegal and should be flagged
   '("[_^]?[=_^][A-Ga-g]"           . 'font-lock-warning-face)
   '("::"                           . 'header-line)
   '("||"                           . 'header-line)
   '("|:"                           . 'header-line)
   '(":|[[]?[0-9]*"                 . 'header-line)
   '("|[0-9]+"                      . 'header-line)
   '("|]"                           . 'header-line)
   '("[[]|"                         . 'header-line)
   '("|[[][1-9]+"                   . 'header-line)
   '("|[1-9]+"                      . 'header-line)
   '("[[][1-9]+"                    . 'header-line)
   '("[[]:"                         . 'header-line)
   '(":]"                           . 'header-line)
   ;; abcpp extensions
   '("^#define"   0 'font-lock-keyword-face t)
   '("^#ifdef"    0 'font-lock-keyword-face t)
   '("^#ifndef"   0 'font-lock-keyword-face t)
   '("^#endif"    0 'font-lock-keyword-face t)
   '("^#else"     0 'font-lock-keyword-face t)
   '("^#include"  0 'font-lock-keyword-face t)
   '("^#undefine" 0 'font-lock-keyword-face t)
   '("^#redefine" 0 'font-lock-keyword-face t)
   )
  "Font-lock highlighting control in abc mode.")

;;; Song number management
(defun abc-current-song-number (&optional noerror)
  "Return the number of the song at the point.

If a song number cannot be found, and NOERROR is true, return nil.  If
NOERROR is false, call `error'.

\"X:\" (actually, `abc-song-number-regexp') lines determine the
boundaries of songs."
  (interactive)
  (save-excursion
    (end-of-line)
    (if (search-backward-regexp abc-song-number-regexp nil t)
        (progn (search-forward-regexp "[0-9]+" nil t)
               (string-to-number (match-string-no-properties 0)))
      (if noerror nil
        (error "Cannot find song number")))))


(defun abc-renumber-songs ()
  "Renumber abc songs in the current buffer."
  (interactive)
  (save-excursion
    (let ((n 1))
      (goto-char (point-min))
      (while (re-search-forward abc-song-number-regexp nil t)
        (beginning-of-line)
        (kill-line)
        (insert (format "%s%d" abc-reference-tag n))
        (setq n (1+ n))))))

(defun abc-crescendo-region ()
  "Surround region with `!crescendo(' and `!crescendo)'."
  (interactive)
  (kill-region (point) (mark))
  (insert "!crescendo(!")
  (yank)
  (insert "!crescendo)!"))


(defun abc-diminuendo-region ()
  "Surround region with `!diminuendo(' and `!diminuendo)'."
  (interactive)
  (kill-region (point) (mark))
  (insert "!diminuendo(!")
  (yank)
  (insert "!diminuendo)!"))


(defun abc-repeat-region ()
  "Surround region with `|:' and `:|'."
  (interactive)
  (kill-region (point) (mark))
  (insert " |: ")
  (yank)
  (insert " :| "))


(defun abc-slur-region ()
  "Surround the region with `(' and ')'."
  (interactive)
  (kill-region (point) (mark))
  (insert "(")
  (yank)
  (insert ")"))


(defun abc-list-buffer-songs ()
  "List the songs in the current buffer."
  (interactive)
  (occur abc-title-regexp)
  (pop-to-buffer "*Occur*"))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Postscript output
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun abc-run-abc2ps-base (argp &optional options)
  "Run abc2ps with the currently selected options on the current buffer.

If prefix argument ARGP is non-nil, query for preprocessor options.
These options will be retained.

Optional argument OPTIONS is program flags not included in the
selected option set."
  (save-buffer)
  (let ((name (abc-preprocess-buffer argp)))
    (shell-command
      (read-from-minibuffer
      "Options: "
      (concat abc-executable
              (if options (concat options " ") " ")
              abc-preferred-options
              " "
              abc-additional-options
              " "
              (file-name-nondirectory name)
              " -O =")))))


(defun abc-run-abc2ps-all (argp &optional options)
  "Run abc2ps on the whole buffer.

If prefix argument ARGP is non-nil, query for preprocessor options.
These options will be retained.

Optional argument OPTIONS is program flags beyond the current option set."
  (interactive "P")
  (abc-run-abc2ps-base argp (concat (if options options ""))))


(defun abc-run-abc2ps-one (argp &optional options)
  "Run abc2ps on the current song.

If prefix argument ARGP is non-nil, query for preprocessor options.
These options will be retained.

Optional argument OPTIONS is program flags beyond the current option set."
  (interactive "P")
  (abc-run-abc2ps-base
   argp
   (concat " -e "
           (number-to-string (abc-current-song-number))
           (if options options ""))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Preprocessor functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun abc-set-preprocess-options (options)
  "Set the preprocessor OPTIONS."
  (interactive "sPreprocessor Options: ")
  (setq abc-pp-options options))

(defun abc-preprocess (argp name &optional midi)
  "Process .abp files into .abp.abc files, if `abc-pp-executable' is non-nil.

If the prefix argument ARGP is non-nil, query for preprocessor options.
These options will be retained.

Argument NAME is the full file name.

Optional argument MIDI inserts `abc-pp-midi-macro' into the argument
list if non-nil.

Returns the name of the output file."
  (interactive "P\nsFile name: ")
  (if argp
      (setq abc-pp-options (read-from-minibuffer "Preprocesor Options: "
                                                 abc-pp-options)))
  (if abc-pp-executable
      (when (string-match "\\.abp$" name)
        (with-temp-buffer
          (if (null midi)
              (if (> (length abc-pp-options) 0)
                  (call-process abc-pp-executable nil t t abc-pp-options name)
                (call-process abc-pp-executable nil t t name))
            (call-process abc-pp-executable nil t t
                          abc-pp-options abc-pp-midi-macro name))
          (write-region 1 (buffer-size) (concat name ".abc")))
        (setq name (concat name ".abc"))))
  name)


(defun abc-preprocess-buffer (argp)
  "Run preprocessor on the current buffer.

If prefix argument ARGP is non-nil, query for preprocessor options.
These options will be retained."
  (interactive "P")
  (abc-preprocess argp (buffer-file-name)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MIDI output
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun abc-run-abc2midi (argp &optional options)
  "Run abc2midi on the current buffer.

If prefix argument ARGP is non-nil, query for preprocessor options.
These options will be retained.

Optional argument OPTIONS is program flags."
  (interactive "P")
  (save-buffer)
  (let ((name (abc-preprocess argp buffer-file-name t)))
    (shell-command
     (read-from-minibuffer
      "Command: "
      (concat abc-midi-executable " "
              (file-name-nondirectory name)
              (if options (concat " " options) ""))))))


(defun abc-run-abc2midi-one (argp &optional options)
  "Run abc2midi on the current song.

If prefix argument ARGP is non-nil, query for preprocessor options.
These options will be retained.

Optional argument OPTIONS is program flags."
  (interactive "P")
  (abc-run-abc2midi argp
                    (concat
                     " "
                     (number-to-string (abc-current-song-number))
                     (if options (concat " " options) ""))))


(defun abc-run-abc2abc (argp)
  "Run abc2abc on the current song.

If prefix argument ARGP is non-nil, query for preprocessor options.
These options will be retained."
  (interactive "P")
  (save-buffer)
  (let ((name (abc-preprocess-buffer argp)))
    (shell-command
     (read-from-minibuffer
      "Command: "
      (concat abc-abc2abc-executable
              " "
              (file-name-nondirectory name))))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Editing functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun abc-forward-song ()
  "Move cursor to the next song."
  (interactive)
  (re-search-forward abc-song-number-regexp nil t))

(defun abc-backward-song ()
  "Move cursor to the previous song."
  (interactive)
  (re-search-backward abc-song-number-regexp nil t))

(defvar abc-mode-old-map
  (let ((map (make-sparse-keymap)))
    ;; enter in reverse order of the desired binding listing
    (define-key map "\M-p"     'abc-backward-song)
    (define-key map "\M-n"     'abc-forward-song)
    (define-key map "\C-c\C-t" 'abc-run-abc2ps-one)
    (define-key map "\C-c\C-s" 'abc-skeleton)
    (define-key map "\C-c\C-p" 'abc-preprocess-buffer)
    (define-key map "\C-c\C-o" 'abc-set-abc2ps-option-set)
    (define-key map "\C-c\C-n" 'abc-renumber-songs)
    (define-key map "\C-c\C-m" 'abc-run-abc2midi)
    (define-key map "\C-c\C-k" 'abc-run-abc2midi-one)
    (define-key map "\C-c\C-l" 'abc-list-buffer-songs)
    (define-key map "\C-c\C-i" 'abc-insert-instrument)
    (define-key map "\C-c\C-dc" 'abc-crescendo-region)
    (define-key map "\C-c\C-dd" 'abc-diminuendo-region)
    (define-key map "\C-c\C-c" 'abc-run-abc2ps-all)
    (define-key map "\C-c\C-a" 'abc-run-abc2abc)
    map)
  "Keymap for abc mode.")

(defvar abc-mode-map
  (let ((map (make-sparse-keymap)))
    ;; enter in reverse order of the desired binding listing
    ;; motion commands
    (define-key map "\M-p"      'abc-backward-song)
    (define-key map "\M-n"      'abc-forward-song)
    (define-key map "\C-c\C-l"  'abc-list-buffer-songs)
    ;; insertion commands
    (define-key map "\C-c\C-s"  'abc-skeleton)
    (define-key map "\C-c\C-n"  'abc-renumber-songs)
    (define-key map "\C-c\C-i"  'abc-insert-instrument)
    ;; C-c C-d prefix for dynamics
    (define-key map "\C-c\C-dc" 'abc-crescendo-region)
    (define-key map "\C-c\C-dd" 'abc-diminuendo-region)
    (define-key map "\C-c\C-ds" 'abc-slur-region)
    ;; C-c C-m prefix for MIDI output
    (define-key map "\C-c\C-mm" 'abc-run-abc2midi)
    (define-key map "\C-c\C-m1" 'abc-run-abc2midi-one)
    ;; C-c C-p prefix for Postscript output
    (define-key map "\C-c\C-po" 'abc-set-abc2ps-option-set)
    (define-key map "\C-c\C-pp" 'abc-run-abc2ps-all)
    (define-key map "\C-c\C-p1" 'abc-run-abc2ps-one)
    ;; C-c C-a abc prefix for abc output
    (define-key map "\C-c\C-aa" 'abc-run-abc2abc)
    (define-key map "\C-c\C-ap" 'abc-preprocess-buffer)
    (define-key map "\C-c\C-ao" 'abc-set-preprocess-options)
    ;; C-c C-c short cut for entering chords
    (define-key map "\C-c\C-c"  'abc-insert-chord)
    map)
  "Keymap for abc mode.")


(easy-menu-define
  abc-mode-menu abc-mode-map
  "Menu used in abc music mode."
  (list "abc"
        ["Forward Song"                 abc-forward-song       t]
        ["Backward Song"                abc-backward-song      t]
        ["List Songs"                   abc-list-buffer-songs  t]
        "--"
        ["New Song"                     abc-skeleton           t]
        ["Renumber Songs"               abc-renumber-songs     t]
        "--"
        (list "Dynamics"
              ["Accent"           (insert "!accent!")      t]
              ["Fermata"          (insert "!fermata!")     t]
              "--"
              ["Crescendo Region" abc-crescendo-region     t]
              ["Diminuendo Region" abc-diminuendo-region   t]
              "--"
              ["pppp"             (insert "!pppp!")        t]
              ["ppp"              (insert "!ppp!")         t]
              ["pp"               (insert "!pp!")          t]
              ["p"                (insert "!p!")           t]
              ["mp"               (insert "!mp!")          t]
              ["mf"               (insert "!mf!")          t]
              ["f"                (insert "!f!")           t]
              ["ff"               (insert "!ff!")          t]
              ["fff"              (insert "!fff!")         t]
              ["ffff"             (insert "!ffff!")        t]
              ["sfz"              (insert "!sfz!")         t]
              "--"
              ["Start Crescendo"  (insert "!crescendo(!")  t]
              ["End Crescendo"    (insert "!crescendo)!")  t]
              ["Start Diminuendo" (insert "!diminuendo("!) t]
              ["End Diminuendo"   (insert "!diminuendo)"!) t]
              )
        (list "Marks"
              ["trill"                  (insert "!trill!")           t]
              ["lowermordent"           (insert "!lowermordent!")    t]
              ["uppermordent"           (insert "!uppermordent!")    t]
              ["mordent"                (insert "!mordent!")         t]
              ["pralltriller"           (insert "!pralltriller!")    t]
              ["accent"                 (insert "!accent!")          t]
              ["emphasis"               (insert "!emphasis!")        t]
              ["fermata"                (insert "!fermata!")         t]
              ["invertedfermata"        (insert "!invertedfermata!") t]
              ["tenuto"                 (insert "!tenuto!")          t]
              ["fingering"              (insert "!0!")               t]
              ["+"                      (insert "!+!")               t]
              ["wedge"                  (insert "!wedge!")           t]
              ["open"                   (insert "!open!")            t]
              ["thumb"                  (insert "!thumb!")           t]
              ["snap"                   (insert "!snap!")            t]
              ["turn"                   (insert "!turn!")            t]
              ["roll"                   (insert "!roll!")            t]
              ["breath"                 (insert "!breath!")          t]
              ["shortphrase"            (insert "!shortphrase!")     t]
              ["mediumphrase"           (insert "!mediumphrase!")    t]
              ["longphrase"             (insert "!longphrase!")      t]
              ["segno"                  (insert "!segno!")           t]
              ["coda"                   (insert "!coda!")            t]
              ["D.S."                   (insert "!D.S.!")            t]
              ["D.C."                   (insert "!D.C.!")            t]
              ["fine"                   (insert "!fine!")            t]
              ["repeatbar"              (insert "!repeatbar!")       t]
              ["repeatbar2"             (insert "!repeatbar2!")      t]
              ["upbow"                  (insert "!upbow!")           t]
              ["downbow"                (insert "!downbow!")         t]
              "Also see Dynamics"
              )
        (list "Bar Lines"
              ["Regular"                       (insert " | ")    t]
              ["Double"                        (insert " || ")   t]
              ["Light Heavy"                   (insert " |] ")   t]
              ["Heavy Light"                   (insert "[| ")    t]
              "--"
              ["Repeat Region"                 abc-repeat-region t]
              ["Start of First Repeat Ending"  (insert " [|1 ")  t]
              ["Start of Second Repeat Ending" (insert " :[|2 ") t]
              ["Repeat Previous"               (insert " :| ")   t]
              ["Repeat Next"                   (insert " |: ")   t]
              ["Repeat Previous and Next"      (insert " :: ")   t]
              )
        ["Slur Region" abc-slur-region t]
        (list "Lyrics"
              ["Syllable Break at Point" (insert "-") t]
              ["Advance to Next Bar" (insert " | ")   t]
              ["Hold Last Syllable" (insert "_")      t]
              ["Skip Note" (insert "*")               t]
              ["Space Within Note" (insert "~")       t]
              ["Literal -" (insert "\\-")             t]
              ["Continue Line" (insert "\\\n")        t]
              )
        (list "Fields"
              "Common Header Fields"
              ["Reference Number (First)"   (insert abc-reference-tag)     t]
              ["Title"                      (insert abc-title-tag)         t]
              ["Lyricist"                   (insert abc-lyricist-tag)      t]
              ["Composer"                   (insert abc-composer-tag)      t]
              ["Meter"                      (insert abc-meter-tag)         t]
              ["Unit Note Length"           (insert abc-length-tag)        t]
              ["Tempo"                      (insert abc-tempo-tag)         t]
              ["Parts"                      (insert abc-parts-tag)         t]
              ["Staves"                     (insert abc-staves-tag " ")    t]
              ["Key (Last)"                 (insert abc-key-tag)           t]
              "--"
              ["Area (deprecated)"          (insert abc-area-tag)          t]
              ["Book"                       (insert abc-book-tag)          t]
              ["Discography"                (insert abc-discography-tag)   t]
              ["File Name (URL)"            (insert abc-filename-tag)      t]
              ["Group"                      (insert abc-group-tag)         t]
              ["History"                    (insert abc-history-tag)       t]
              ["Information"                (insert abc-information-tag)   t]
              ["Notes"                      (insert abc-notes-tag)         t]
              ["Origin (place)"             (insert abc-origin-tag)        t]
              ["Rhythm"                     (insert abc-rhythm-tag)        t]
              ["Source"                     (insert abc-source-tag)        t]
              ["User Defined"               (insert abc-user-tag)          t]
              ["Words (at End)"             (insert abc-words-end-tag)     t]
              ["Words (Internal)"           (insert abc-words-tag)         t]
              "--"
              "Extended Information"
              ["ABC version"                (insert abc-version-tag)       t]
              ["ABC copyright"              (insert abc-copyright-tag)     t]
              ["ABC creator"                (insert abc-creator-tag)       t]
              ["ABC charset"                (insert abc-charset-tag)       t]
              ["ABC include"                (insert abc-include-tag)       t]
              ["ABC edited-by"              (insert abc-edited-by-tag)     t]
              )
        (list "MIDI"
              ["Melody Channel (1-16)"    (insert "%%MIDI channel ") t]
              (cons "Instrument"
                    (mapcar
                     (lambda (l)
                       (vector (car l)
                               (list 'insert
                                     (list 'format "%d %% %s\n"
                                           (cdr l) (car l)))))
                     abc-midi-instruments-alist))
              (cons "Main Instrument"
                    (mapcar
                     (lambda (l)
                       (vector
                        (car l)
                        (list 'insert
                              (list 'format "%%%%MIDI program %d %% %s\n"
                                    (cdr l) (car l)))))
                     abc-midi-instruments-alist))
              (cons "Bass Instrument"
                    (mapcar
                     (lambda (l)
                       (vector
                        (car l)
                        (list 'insert
                              (list 'format
                                    "%%%%MIDI bassprog %d %% %s\n"
                                    (cdr l) (car l)))))
                     abc-midi-instruments-alist))
              (cons "Chord Instrument"
                    (mapcar
                     (lambda (l)
                       (vector
                        (car l)
                        (list 'insert
                              (list 'format
                                    "%%%%MIDI chordprog %d %% %s\n"
                                    (cdr l) (car l)))))
                     abc-midi-instruments-alist))
              ["Insert Instrument"        abc-insert-instrument           t]
              "--"
              ["Insert Chord Definitions" abc-midi-chords                 t]
              ["Insert Default Chord Definitions"
               (insert abc-midi-default-chord-list)                       t]
              ["Turn On Guitar Chords"    (insert "%%MIDI gchordon\n")    t]
              ["Turn Off Guitar Chords"   (insert "%%MIDI gchordoff\n")   t]
              "--"
              ["Chord Volume"             (insert "%%MIDI chordvol ")     t]
              ["Bass Volume"              (insert "%%MIDI bassvol ")      t]
              "--"
              ["Start Drum"               (insert " !drum! ")             t]
              ["Stop Drum"                (insert " !nodrum! ")           t]
              )
        "--"
        "Postscript"
        ["Run abc2ps (buffer)"          abc-run-abc2ps-all        t]
        ["Run abc2ps (song)"            abc-run-abc2ps-one        t]
        ["Set abc2ps Options"           abc-set-abc2ps-option-set t]
        (cons "Select Option Set"
              (mapcar
               (lambda (l)
                 (vector (car l)
                         (list 'setq 'abc-preferred-options (cdr l))
                         :style 'radio :selected
                         (list 'string= 'abc-preferred-options (cdr l))))
               abc-option-alist))
        "--"
        "MIDI"
        ["Run abc2midi (buffer)"        abc-run-abc2midi       t]
        ["Run abc2midi (song)"          abc-run-abc2midi-one   t]
        "--"
        ["Preprocess Buffer"            abc-preprocess-buffer       t]
        ["Set Preprocess Options..."    abc-set-preprocess-options  t]
        "--"
        ["Run abc2abc"                  abc-run-abc2abc        t]
        "--"
        ["Enable Mouse Input"           abc-mouse              t]
        ["Remove Mouse Window"          delete-other-windows   t]
        ))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Mouse input functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun abc-mouse ()
  "Enable mouse input for abc mode.

Creates or selects a buffer in the other window.  By clicking on a
symbol, you can insert it in the abc buffer.  Special symbols are
described below.  The contents of the mouse buffer can be changed as
desired, or customized by changing `abc-mouse-pad'.

Special symbols (BS, SPACE, NL, undo, etc.) are defined in
`abc-mouse-specials'."
  (interactive)
  (save-excursion
    (let ((newp (null (get-buffer "*abc-notes*"))))
      (switch-to-buffer-other-window "*abc-notes*")
      (if newp (insert abc-mouse-pad))
      (goto-char 1)
      (enlarge-window
       (1+ (- (count-lines (point-min) (point-max)) (window-height)))))
    (local-set-key [mouse-1] 'abc-insert-mouse-note-other))
  (other-window 1))

(defun abc-insert-mouse-note-other (event)
  "Insert the selected symbol in the other window at its point.
Argument EVENT is the mouse event."
  (interactive "e")
  (save-excursion
    (let ((note (abc-cursor-to-note)))
      (other-window 1)
      (abc-insert-note-string note))))

(defun abc-insert-note-string (str)
  "Insert STR, or carry out the appropriate action (see `abc-mouse-specials')."
  (cond ((null str) (ignore))
        ((assoc str abc-mouse-specials)
         (funcall (cdr (assoc str abc-mouse-specials))))
        (t (insert str))))

(defun abc-cursor-to-note ()
  "Get the space delimited string at the point."
  (if (looking-at "[[:space:]\n]")
      (progn
        (message "Not a symbol.")
        nil)
    (or (re-search-backward "[[:space:]]" (point-min) t)
        (goto-char (point-min)))
    (re-search-forward "[^[:space:]]")
    (backward-char)
    (re-search-forward "\\([^[:space:]\n]+\\)")
    (match-string-no-properties 1)))

(defun abc-event-to-note ()
  "Symbol at the event position (mouse click)."
  (with-current-buffer
    (set-buffer (window-buffer (posn-window (event-start last-input-event))))
    (goto-char (posn-point (event-start last-input-event)))
    (abc-cursor-to-note)))


;;;###autoload
(define-derived-mode abc-mode text-mode "abc-mode"
   "Major mode for editing abc music files.

The preprocessor (if present) is automatically run before abc2ps and
abc2MIDI (also abc2abc, see `abc-preprocess').  If abc2MIDI is run,
the preprocessor is run with an additional macro flag specified by
`abc-pp-midi-macro'.

Basic Commands
===== ========

Editing Songs
------- -----
\\[abc-skeleton]\tinsert new song (`abc-skeleton')
\\[abc-insert-instrument]\tinsert MIDI instrument
\\[abc-renumber-songs]\trenumber songs in buffer
\\[abc-mouse]\tenable mouse input

Motion Commands
------ --------
\\[backward-sentence]\tbeginning of bar (or sentence if in text)
\\[forward-sentence]\tend of bar (or sentence)
\\[abc-forward-song]\tforward song
\\[abc-backward-song]\tbackward song
\\[abc-list-buffer-songs]\tlist songs in the current buffer

If `abc-use-song-as-page-delimiter' is non-nil, page motion commands
will consider songs to mark page boundaries.

Musical Insertions
------- ----------
\\[abc-slur-region]\tplace slur mark around the region
\\[abc-diminuendo-region]\tplace diminuendo mark around the region
\\[abc-crescendo-region]\tplace crescendo mark around the region

abc2ps Commands (Postscript output)
------ --------
The universal prefix arg will cause prompting for preprocessor options.
\\[abc-run-abc2ps-all]\trun on the buffer (prompts for options)
\\[abc-run-abc2ps-one]\trun on current song (prompts for options)
\\[abc-set-abc2ps-option-set]\tset the default option set

abc2midi Commands (MIDI output)
-------- --------
The universal prefix arg will cause prompting for preprocessor options.
\\[abc-run-abc2midi]\trun on the buffer (prompts for options)
\\[abc-run-abc2midi-one]\trun on current song (prompts for options)

abc2abc Commands (abc output)
------- --------
The universal prefix arg will cause prompting for preprocessor options.
\\[abc-run-abc2abc]\trun abc2abc on the buffer

abcpp Commands (abc output)
----- --------
The universal prefix will cause prompting for preprocessor options.
\\[abc-preprocess-buffer]\trun the preprocessor on the buffer

This package is very customizable.  See the abc-mode group.  Run
\\[abc-customize] for easy access.

Check `abc-font-lock-keywords' for compatibility with the local
installation.

Use TeX-type quoting `` & '' for double quotes in lyrics.

\\{abc-mode-map}"
   (kill-all-local-variables)
   (use-local-map        abc-mode-map)
   (easy-menu-add        abc-mode-menu)
   (set-syntax-table     abc-mode-syntax-table)
   (setq major-mode          'abc-mode
         mode-name           "abc"
         comment-start       abc-mode-comment-start
         comment-end         ""         ; blank = EOL
         comment-start-skip  "\\(\\(^\\|[^\\\\\n]\\)\\(\\\\\\\\\\)*\\)%+ *"
         ;;        parse-sexp-ignore-comments t
         )
   (set-syntax-table abc-mode-syntax-table)

   (make-local-variable 'sentence-end)
   ;; make bars equivalent to sentences
   (setq sentence-end (concat "|\\|" sentence-end))

   (set (make-local-variable 'font-lock-defaults)
        '(abc-font-lock-keywords nil nil))
   (make-local-variable 'abc-options)
   (if abc-use-song-as-page-delimiter
       (set (make-local-variable 'page-delimiter)
            abc-song-number-regexp))
   (run-hooks 'abc-mode-hook))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Data insertion aids
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun abc-insert-instrument (&optional prompt)
  "Prompt for and insert the number and commented name of a MIDI instrument.
Optional argument PROMPT is the prompt to show."
  (interactive)
  (let ((instrument
         (cdr (assoc (completing-read
                      (if prompt
                          (concat prompt " MIDI instrument: ")
                        "MIDI instrument: ")
                      abc-midi-instruments-alist nil t
                      nil 'abc-instrument-history)
                     abc-midi-instruments-alist))))
    (if instrument
        (progn
          (insert (number-to-string instrument))
          (insert " % " (car (rassoc instrument abc-midi-instruments-alist)))
          t)
      nil)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Skeleton
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-skeleton abc-staves "" "" \n abc-staves-tag " {"
  ("Staff #: " " " str) & " }" | -11)

(define-skeleton abc-midi-chords
  "MIDI chords in addition to the predefined ones."
  nil
  abc-midi-chord-list
  _)


;;;###autoload
(define-skeleton abc-skeleton
  "Skeleton for a song"
  nil
  abc-reference-tag
  (if (abc-current-song-number t)
      (number-to-string (1+ (abc-current-song-number t)))
    "1")
  ("Title: "    \n abc-title-tag str)
  \n abc-filename-tag "$Id: abc-mode.el 906 2013-01-11 15:52:26Z junker $"
  ("Lyricist: " \n abc-lyricist-tag str)
  ("Composer: " \n abc-composer-tag str)
  ("Book (original source): "     \n abc-book-tag str)
  ("Source (current source): "   \n abc-source-tag str)
  ("Notes (alternate sources, copyright): "   \n abc-notes-tag str)
  \n abc-meter-tag (skeleton-read "Meter: " abc-default-meter nil)
  \n abc-length-tag (skeleton-read "Default length: " abc-default-length nil)
  \n abc-tempo-tag (skeleton-read "Tempo: " abc-default-tempo nil)
  '(abc-staves)
  \n abc-key-tag (skeleton-read "Key: " abc-default-key nil)
  "\n%%MIDI program "
  '(unless (abc-insert-instrument "Main")
     (beginning-of-line) (kill-line) (backward-char))
  "\n%%MIDI bassprog "
  '(unless (abc-insert-instrument "Bass")
     (beginning-of-line) (kill-line) (backward-char))
  "\n%%MIDI chordprog "
  '(unless (abc-insert-instrument "Chord")
     (beginning-of-line) (kill-line) (backward-char))
;  \n "% %%MIDI gchord fzczfzcz"
;  \n "% %%MIDI beatstring fmfm"
;  \n "%V: 1"
;  \n "%w:"
;  \n "%V: 2"
  \n _)

;;;###autoload
(defun abc-align-bars (begin end)
  "Align on bar lines \"|\" between BEGIN and END (region)."
  (interactive "r")
  (add-to-list 'align-text-modes 'abc-mode)
  (save-excursion
    (goto-char begin)
    (while (re-search-forward "[ ]+|[ ]+" end t)
      (replace-match " | ")))
  (align-regexp begin end "\\(.\\)|" 1 1 t))

(defvar abc-chord-history nil
  "Recent chord entries.  Used by `abc-insert-chord'.")

(defun abc-insert-chord ()
  "Insert chord symbol with quotes."
  (interactive)
  (insert "\"")
  (let ((input (read-from-minibuffer
                "Chord: " nil nil nil 'abc-chord-history nil)))
    (insert input)
    (add-to-history 'abc-chord-history input))
  (insert "\""))

;;;###autoload
(defun abc-customize ()
  "Customize `abc-mode' settings."
  (interactive)
  (customize-group 'abc-mode))

(defun abc-extract-chords ()
  "Leave only chords, rests, and bar lines on the current line."
  (interactive)
  (save-restriction
    (narrow-to-region (line-beginning-position) (line-end-position))
    (beginning-of-line)
    (while (< (point) (line-end-position))
      (cond ((looking-at "\".*?\"") (goto-char (match-end 0)))
            ((looking-at "[A-Ga-g]")
             (kill-region (match-beginning 0) (match-end 0))
             (insert "x"))
            ((looking-at "[',()^_=]") (delete-char 1))
            ((looking-at "[[]") (delete-char 1))
            ((looking-at "[]]") (delete-char 1))
            (t (forward-char))))))

(provide 'abc-mode)
;;; abc-mode.el ends here
