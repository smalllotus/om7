;============================================================================
; om7: visual programming language for computer-aided music composition
; Copyright (c) 2013-2017 J. Bresson et al., IRCAM.
; - based on OpenMusic (c) IRCAM 1997-2017 by G. Assayag, C. Agon, J. Bresson
;============================================================================
;
;   This program is free software. For information on usage 
;   and redistribution, see the "LICENSE" file in this distribution.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
;
;============================================================================
; File author: J. Bresson
;============================================================================


(in-package :om)

;;;====================================================
;;; DRAW METHODS FOR SCORE EDITOR / MINIVIEW
;;;====================================================

;;; MINIVIEW
(defmethod score-object-mini-view ((self voice) box x-pix y-u w h)
  
  (draw-staff x-pix y-u w h (fontsize box) (get-edit-param box :staff) :margin-l 1 :margin-r 1 :keys t)

  (loop for m in (inside self)
        for i from 1
        do (draw-score-element m (tempo self) box (frame box) :y-shift y-u :font-size (fontsize box) :position i)
        ))


;;; EDITOR
(defmethod draw-sequence ((object voice) editor view unit)

  ;;; NOTE: so far we don't build/update a bounding-box for the containers
  
  (let ((on-screen t))
    (loop for m in (inside object)
          for i from 1
          while on-screen
          do (let* ((begin (beat-to-time (symbolic-date m) (tempo object)))
                    (end (beat-to-time (+ (symbolic-date m) (r-ratio-value (symbolic-dur m))) (tempo object)))
                    (x1 (time-to-pixel view begin))
                    (x2 (time-to-pixel view end)))
               
               (if (> x1 (w view)) (setf on-screen nil)
                 ;;; else :
                 (when (> x2 0) 
                   
                   ;;; DRAW THIS MEASURE
                   (draw-score-element m (tempo object) (object editor) view :position i
                                       :font-size (editor-get-edit-param editor :font-size)
                                       :selection (selection editor))
                   )))
          ))
  )


;;;===============================================
;;; MEASURE
;;;===============================================

(defmethod draw-score-element ((object measure) tempo param-obj view 
                               &key font-size (y-shift 0) (level 0) position beam-info selection)

  (declare (ignore level beam-info))

  (let ((x-pix (time-to-pixel view (beat-to-time (symbolic-date object) tempo))))
    
    (unless (= position 1) 
      (draw-measure-bar x-pix y-shift font-size (get-edit-param param-obj :staff))
      (om-draw-string x-pix (- y-shift 1) (number-to-string position)
                      :font (om-def-font :font1 :size (/ font-size 3))))
                   
    (loop for element in (inside object) 
          for i from 0 do
          (draw-score-element element tempo param-obj view 
                              :level 1
                              :position i
                              :y-shift y-shift
                              :font-size font-size
                              :selection selection))
    ))

;;;========================
;;; BEAMING / GROUPS
;;;========================

;;; select up or down according to the mean-picth in this group vs. center of the current staff
;;; accordingly, the beam-point is <beam-size> above max pitch, or below min-pitch
(defmethod find-group-beam-line ((self group) staff)
  
  (let* ((medium (staff-medium-pitch staff))
         (chords (get-all-chords self)) ;;; can be nil if only rests !!
         (pitches (loop for c in chords append (mapcar 'midic (inside c))))
         (p-max (list-max pitches)) (p-min (list-min pitches))
         (mean (if pitches 
                   ;(/ (apply '+ pitches) (length pitches)) 
                   (* (+ p-max p-min) .5)
                 7100)) ;;; default = B4
         (max-beams (list-max (mapcar #'(lambda (c) 
                                              (get-number-of-beams (r-ratio-value (symbolic-dur c))))
                                          chords))))
    ;(print max-beams)
    (if (<= mean medium) 
        ;;; up
        (values (+ (pitch-to-line p-max) *stem-height* (* max-beams .5)) :up)
      ;;; down
      (values (- (pitch-to-line p-min) *stem-height* (* max-beams .5)) :down)
      )
    ))


(defun find-group-symbol (val)
  (let* ((den (denominator val))
         (bef (bin-value-below den)))
    (list 
     (note-strict-beams (/ 1 bef)) 
     (denominator (/ bef den)))))

(defun note-strict-beams (val)
   (cond
    ((or (= val 1/4) (= val 1/2) (>= val 1)) 0)
    ((= val 1/8)  1)
    ((= val 1/16) 2)
    ((= val 1/32) 3)
    ((= val 1/64) 4)
    ((= val 1/128) 5)
    ((= val 1/256) 6)
    ((= val 1/512) 7)
    ((is-binaire? val) (round (- (log (denominator val) 2) 2)))
    (t (find-group-symbol val))))

;;; gives number of beams for a given division
;;; might return a list if the denominator is not a power of two
;;; => entry in the process of determining the beaming for a given chord.
;;; this code is directly adapted from OM6 score editors
(defun get-beaming (val)
  
  (let* ((num (numerator val))
         (den (denominator val))
         (bef (bin-value-below num)))
    
     (cond
      ((= bef num)
       (note-strict-beams (/ num den)))
      
      ((= (* bef 1.5) num)
       (note-strict-beams (/ bef den)))
       
      ((= (* bef 1.75) num)
       (note-strict-beams (/ bef den)))

      (t 0))
     ))


(defun get-number-of-beams (val)
  (let ((beams (get-beaming val)))
    (if (listp beams) (car beams) beams)))
  

(defmethod beam-num ((self score-object) dur)
  (get-number-of-beams dur))

;;; gets the minimum number of beams in a group
(defmethod beam-num ((self group) dur)
 
  (let ((nd (or (numdenom self) (list 1 1))))  
    ;; (print (list "G" (tree self) (numdenom self) (symbolic-dur self) dur (get-group-ratio (tree self))))
    
    (loop for element in (inside self)
          minimize (beam-num element (* (/ (car nd) (cadr nd)) 
                                        (/ (r-ratio-value (symbolic-dur element))
                                           (r-ratio-value (symbolic-dur self))) 
                                        dur)))
    ))


;;; Get the depth of num/dem line in a group
(defmethod calcule-chiff-level ((self t)) 0)
(defmethod calcule-chiff-level ((self group))
  (+ (if (numdenom self) 1 0) 
     (loop for item in (inside self)
           maximize (calcule-chiff-level item))))

                     
;;; beam-info : (beam-pos beam-direction beams-already-drawn parent-dur parent-denom)
(defmethod draw-score-element ((object group) tempo param-obj view 
                               &key font-size (y-shift 0) (level 1) position beam-info selection)
  
  (declare (ignore position))
  
  ;(print (list "=========="))
  ;(print (list "GROUP" (tree object) (numdenom object) (symbolic-dur object)))

  (let* ((staff (get-edit-param param-obj :staff))
         (beam-n-and-dir (or (first-n beam-info 2) ;; the rest of the list is local info
                             (multiple-value-list (find-group-beam-line object staff))))
         (beams-from-parent (nth 2 beam-info))
         ;; (r-unit (or (nth 3 beam-info) 1))
         (nd (or (numdenom object) (list 1 1)))
         (chords (get-all-chords object))
         (pix-beg (time-to-pixel view (beat-to-time (symbolic-date (car chords)) tempo) ))
         (pix-end (time-to-pixel view (beat-to-time (symbolic-date (car (last chords))) tempo) ))
         
         (n-beams (beam-num object (r-ratio-value (symbolic-dur object))))
         (group-beams (arithm-ser 1 n-beams 1))
         
         )
         
    ;;; local variables for the loop
    (let ((beams-drawn-in-sub-group nil))
    
      ;; the first group catching a beam information transfers to all descendants  
      (loop with sub-group-beams = 0
            for element in (inside object)
            for i from 0 do
            
            ;; (print (list element i))
            
            ;;; here we hanlde "virtual sub-group" displayed as tied beams
            ;;; when a sucession of atomic elements have the same beaming
            (unless (typep element 'group)

              (let*  ((graphic-dur (* (r-ratio-value (symbolic-dur element)) (/ (car nd) (cadr nd))))
                      (n-beams-in-current (beam-num element graphic-dur))
                      (prev (previous-in-list (inside object) element nil))
                      (next (next-in-list (inside object) element nil))
                      (n-beams-in-previous (and prev (beam-num prev (* (r-ratio-value (symbolic-dur prev)) (/ (car nd) (cadr nd))))))
                      (n-beams-in-next (and next (beam-num next (* (r-ratio-value (symbolic-dur next)) (/ (car nd) (cadr nd)))))))
              
                (when  (> n-beams-in-current sub-group-beams) 
                  ;;; first of a new "sub-group" (same number of sub-beams) 
                  ;;; will draw additional single-beams on the right if any
                  
                  (setq sub-group-beams n-beams-in-current)
                  
                  ;;; if there's more beams on the right than on the left, individual beam will be towards right 
                  ;;; => to do so, position in group is artificially reset to 0
                  (when (and prev next 
                             (not (typep next 'group)) ;; also if this one is the last of its group
                             (> n-beams-in-next n-beams-in-previous))
                    (setq i 0))
                  )
                 
                
                (when (and (> n-beams-in-current n-beams) ;;; more beams than the current "real" container group
                           (> i 0)) ;;; this is not the 1st element
                  
                  (setq beams-drawn-in-sub-group (arithm-ser 1 (min n-beams-in-current (or n-beams-in-previous 0)) 1))
                          
                  ;;; draw beams between i and (i-1) and update the beaming count for sub-elements
                  (draw-beams (time-to-pixel view (beat-to-time (symbolic-date prev) tempo))
                              (time-to-pixel view (beat-to-time (symbolic-date element) tempo))
                              (car beam-n-and-dir)  ;; the beam init line
                              (cadr beam-n-and-dir) ;; the beam direction
                              beams-drawn-in-sub-group  ;; the beam numbers 
                              y-shift staff font-size)
                  )))
                
              

            (draw-score-element element tempo param-obj view 
                                :y-shift y-shift
                                :font-size font-size
                                :level (1+ level) 
                                :beam-info (when beam-n-and-dir (list 
                                                                 (nth 0 beam-n-and-dir)
                                                                 (nth 1 beam-n-and-dir)
                                                                 ;;; send the beams already drawn in 3rd position
                                                                 ;group-beams
                                                                 (append group-beams beams-drawn-in-sub-group)
                                                                 nd
                                                                 ))
                                :position i
                                :selection selection)
            ))

    ;;; sub-groups or chords wont have to draw these beams
    (draw-beams pix-beg pix-end
                (car beam-n-and-dir)  ;; the beam init line
                (cadr beam-n-and-dir) ;; the beam direction
                (set-difference group-beams beams-from-parent)   ;; the beam numbers 
                y-shift staff font-size)
   
    ;;; subdivision line and numbers 
    (when (numdenom object)
      (let* ((numdenom-level (calcule-chiff-level object)))
        ;;; chiflevel tells us how much above or below the beam this should be placed
        ;; (print (list object chiflevel (numdenom object)))
        (draw-group-div (numdenom object)
                        numdenom-level
                        pix-beg pix-end
                        (car beam-n-and-dir)  ;; the beam init line
                        (cadr beam-n-and-dir) ;; the beam direction
                        y-shift staff font-size)
        ))
    )
  )



#|
;;; passed through groups as "durtot" in OM6:2
;;; starting at (* symb-beat-val factor) in measure

 (real-beat-val (/ 1 (fdenominator (first tree))))
 (symb-beat-val (/ 1 (find-beat-symbol (fdenominator (first tree)))))
 (dur-obj-noire (/ (extent item) (qvalue item)))
 (factor (/ (* 1/4 dur-obj-noire) real-beat-val))
 (unite (/ durtot denom))
;;; => 

;;; NO GROUP RATIO:
   (let* ((dur-obj (/ (/ (extent item) (qvalue item)) 
                      (/ (extent self) (qvalue self)))))
     (* dur-obj durtot))

;;; GROUP RATIO:
   (let* ((operation (/ (/ (extent item) (qvalue item)) 
                        (/ (extent self) (qvalue self))))
          (dur-obj (numerator operation)))
     (setf dur-obj (* dur-obj (/ num (denominator operation))))
     (* dur-obj unite)))

;;; passed through groups as "ryth"
;;; starting at  (list real-beat-val (nth i (cadr (tree self)))) in measure
;;; => 
(list (/ (car (second ryth)) (first ryth))
      (nth i (cadr (second ryth))))

|#


;;;===================
;;; CHORD
;;;===================


(defmethod draw-score-element ((object chord) 
                               tempo param-obj view 
                               &key font-size (y-shift 0) (level 1) (position 0) beam-info selection)
  

  (let* ((begin (beat-to-time (symbolic-date object) tempo))
         (s-dur (symbolic-dur object))
         
         (staff (get-edit-param param-obj :staff))
         (chan (get-edit-param param-obj :channel-display))
         (vel (get-edit-param param-obj :velocity-display))
         (port (get-edit-param param-obj :port-display))
         (dur (get-edit-param param-obj :duration-display))

         (parent-nd (nth 3 beam-info))
         (parent-ratio (if parent-nd (/ (car parent-nd) (cadr parent-nd)) 1))
         ;; (graphic-dur (* (/ (r-ratio-num s-dur) (bin-value-below (r-ratio-denom s-dur))) parent-ratio))
         (graphic-dur (* (r-ratio-value s-dur) parent-ratio))
         ;;; from OM6.. 
         (beams-num (get-number-of-beams graphic-dur))
         (beams-from-parent (nth 2 beam-info))
         (beams-to-draw (set-difference (arithm-ser 1 beams-num 1) beams-from-parent))
         ;; (propre-group (if (listp beams) (cadr beams)))

         (draw-bboxes (typep view 'score-panel))
         )
    
    ;(print (list "chord" s-dur parent-nd graphic-dur))
    ;; in fact propre-group (= when a standalone chord has a small group indication) will never happen (in OM)
    
    (let ((bbox? 
           (draw-chord object
                       begin
                       y-shift 
                       (w view) (h view) 
                       font-size
                       :head (multiple-value-list (note-head-and-points graphic-dur))
                       :stem (or (= level 1) (car beam-info))  ;; (car beam-info) is the beam-line 
                       :beams (list beams-to-draw position)
                       :staff staff
                       :draw-chans chan
                       :draw-vels vel
                       :draw-ports port
                       :draw-durs dur
                       :selection (if (find object selection) T selection)
                       :time-function #'(lambda (time) (time-to-pixel view time))
                       :build-b-boxes draw-bboxes
                       )))
      
      (when draw-bboxes
        (setf (b-box object) bbox?))
      
      bbox?)))
      



;;;===================
;;; CONTINUATION-CHORD
;;;===================

(defmethod draw-score-element ((object continuation-chord) 
                               tempo param-obj view 
                               &key font-size (y-shift 0) (level 1) (position 0) beam-info selection)
  

  (let* ((begin (beat-to-time (symbolic-date object) tempo))
         (staff (get-edit-param param-obj :staff))
         
         (s-dur (symbolic-dur object))
         
         (parent-nd (nth 3 beam-info))
         (parent-ratio (if parent-nd (/ (car parent-nd) (cadr parent-nd)) 1))
         ;(graphic-dur (if (= 1 parent-ratio) (/ (r-ratio-num s-dur) 4) (* s-dur parent-ratio)))
         (graphic-dur (* (r-ratio-value s-dur) parent-ratio))
        
         ;;; from OM6.. 
         (beams-num (get-number-of-beams graphic-dur))
         (beams-from-parent (nth 2 beam-info))
         (beams-to-draw (set-difference (arithm-ser 1 beams-num 1) beams-from-parent))
         ;;(propre-group (if (listp beams) (cadr beams)))
         
         (draw-bboxes (typep view 'score-panel))
         )
    
    ;(print (list "cont-chord" (symbolic-dur object) parent-nd graphic-dur))

    (let ((bbox? 
           (draw-chord (previous-chord object)
                       begin
                       y-shift 
                       (w view) (h view) 
                       font-size
                       :head (multiple-value-list (note-head-and-points graphic-dur))
                       :stem (or (= level 1) (car beam-info))  ;; (car beam-info) is the beam-line 
                       :beams (list beams-to-draw position)
                       :staff staff
                       :selection (if (find object selection) T selection)
                       :tied-to (previous-chord object)
                       :time-function #'(lambda (time) (time-to-pixel view time))
                       :build-b-boxes nil
                       )))
      
      (when draw-bboxes
        (setf (b-box object) bbox?))
      
      (draw-tie object view font-size tempo)
      
      bbox?)
    ))


;;;=========
;;; REST
;;;=========

(defmethod draw-score-element ((object r-rest) tempo param-obj view &key font-size (y-shift 0) (level 1) position beam-info selection)
  
  (let* ((begin (beat-to-time (symbolic-date object) tempo)))
        
    (setf 
     (b-box object)
     (draw-rest object
                begin
                y-shift 
                (w view) (h view) 
                font-size 
                :head (multiple-value-list (rest-head-and-points (r-ratio-value (symbolic-dur object))))
                :staff (get-edit-param param-obj :staff)
                :selection (if (find object selection) T selection)
                :time-function #'(lambda (time) (time-to-pixel view time))
                :build-b-boxes t
                ))
    ))



;;; todo
;;; LONG-HEADS (see draw-chord)
;;; RESTS: GROUPS/BEAMING AND Y-POSITIONS
;;; TEMPO / CHIFFRAGE MESURE
;;; SPACING
;;; TEMPO CHANGE
;;; GRACE NOTES



