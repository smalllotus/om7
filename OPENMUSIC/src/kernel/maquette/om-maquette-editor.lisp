;;; NEW MAQUETTE / SEQUENCER WINDOW

(in-package :om)

(defparameter *track-control-w* 100)
(defparameter *track-h* 40)
(defparameter +maq-bg-color+ (om-gray-color 0.65))
(defparameter +track-color-1+ (om-gray-color 0.5))
(defparameter +track-color-2+ (om-gray-color 0.6))
(defparameter +font-color+ (om-gray-color 1))

(defclass maquette-editor (patch-editor multi-view-editor play-editor-mixin) 
  ((view-mode :accessor view-mode :initarg :view-mode :initform :tracks)
   (snap-to-grid :accessor snap-to-grid :initarg :snap-to-grid :initform t)
   (beat-info :accessor beat-info :initarg :beat-info :initform (list :beat-count 0
                                                                      :prevtime 0
                                                                      :nexttime 1))))

(defmethod get-editor-class ((self OMMaquette)) 'maquette-editor)
(defmethod get-obj-to-play ((self maquette-editor)) (object self))

(defmethod get-editor-view ((self maquette-editor))
  (if (equal (view-mode self) :maquette)
      (get-g-component self :maq-view)
    (selected-view self))) ;; selected = the last clicked

(defmethod get-view-from-mode ((self maquette-editor))
  (if (equal (view-mode self) :maquette)
      (get-g-component self :maq-view)
    (get-g-component self :track-views)))

(defmethod n-tracks ((self maquette-editor)) 
  (max 4
       (if (boxes (object self))
           (list-max (mapcar 'group-id (get-all-boxes (object self))))
         0 )))

(defmethod get-range ((self maquette-editor)) (range (object self)))

(defmethod get-tempo-automation ((self maquette-editor))
  (tempo-automation (get-g-component self :metric-ruler)))

(defmethod cursor-panes ((self maquette-editor)) 
  (remove nil
          (append (list (get-g-component self :maq-view)
                        (get-g-component self :metric-ruler)
                        (get-g-component self :abs-ruler))
                  (get-g-component self :track-views))))

(defmethod move-editor-selection ((self maquette-editor) &key (dx 0) (dy 0))
  (loop for tb in (get-selected-boxes self) do
        (move-box-in-maquette (object self) tb :dx dx :dy dy)))

(defmethod box-at-pos ((editor maquette-editor) time &optional track)
  (let* ((maquette (object editor)))
    (find time (if track (get-track-boxes maquette track) (get-all-boxes maquette))
          :test #'(lambda (tt tb)
                    (and (> tt (get-box-onset tb)) (< tt (+ (get-box-onset tb) (get-box-duration tb))))))))


(defmethod new-box-in-maq-editor ((self maquette-editor) at &optional (track 0))
  (let ((maq (object self))
        (new-box (omng-make-new-boxcall 'patch at)))
    (add-box-in-track maq new-box track)  
    new-box))

(defmethod select-all-command ((self maquette-editor))
  #'(lambda () (select-unselect-all self t)
      (om-invalidate-view (window self))))

(defmethod get-internal-view-components ((self patch-editor))
  (let ((editorview (main-view (window self))))
    (append (get-boxframes self)
            (get-grap-connections self))))


;;;========================
;;; EDITOR WINDOW
;;;========================

(defclass maquette-editor-window (OMEditorWindow) ())
(defmethod editor-window-class ((self maquette-editor)) 'maquette-editor-window)


(defmethod update-to-editor ((self maquette-editor) (from t))
  (om-invalidate-view (window self)))

(defmethod report-modifications ((self maquette-editor))
  (call-next-method)
  (om-invalidate-view (window self)))

(defmethod editor-window-init-size ((self maquette-editor)) (om-make-point 800 500))

;;; redefined from patch editor
(defmethod init-window ((win maquette-editor-window) editor)
  (call-next-method)
  ;(when (equal (view-mode editor) :maquette) 
  ;  (put-patch-boxes-in-editor-view (object editor) (get-g-component editor :maq-view)))
  (update-window-name editor)
  win)


;;;========================
;;; MAQUETTE-VIEW
;;;========================

(defclass maquette-view (patch-editor-view multi-view-editor-view x-cursor-graduated-view om-drop-view) ())
;(defmethod editor-view-class ((self maquette-editor)) 'maquette-view)

(defmethod omng-position ((container maquette-view) position)
  (omp (pix-to-x container (om-point-x position))
       (om-point-y position)))

(defmethod omg-position ((container maquette-view) position) 
  (omp (x-to-pix container (om-point-x position))
       (om-point-y position)))

(defmethod resize-handle ((self resize-area) (container maquette-view) frame pos) 
  (let ((pp (om-add-points (p0 self) pos)))
    (om-set-view-size frame 
                      (om-max-point
                       (om-make-point 10 20)
                       (resize-frame-size self frame pp)))))

(defmethod update-temporalboxes ((self maquette-view))
  (loop for sv in (get-boxframes self) do
        (let* ((box (object sv))
               (x1 (x-to-pix self (box-x box)))
               (x2 (x-to-pix self (+ (box-x box) (box-w box)))))
          (om-set-view-position sv (om-point-set (om-view-position sv) :x x1))
          (om-set-view-size sv (om-point-set (om-view-size sv) :x (- x2 x1)))
          (redraw-connections sv)
          )))

(defmethod update-view-from-ruler ((self x-ruler-view) (view maquette-view))
  (call-next-method)
  (setf (car (range (object (editor view)))) (x1 self)
        (cadr (range (object (editor view)))) (x2 self))
  (update-temporalboxes view))

(defmethod om-view-resized :after ((view maquette-view) new-size)
  (declare (ignore new-size))
  (update-temporalboxes view))


;;;========================
;;; TRACK-VIEW
;;;========================
(defclass sequencer-track-view (multi-view-editor-view x-cursor-graduated-view omframe om-drop-view om-view)
  ((num :initarg :num :initform 0 :accessor num)))

(defclass sequencer-track-control (om-view)
  ((num :initarg :num :initform 0 :accessor num)))

(defmethod om-draw-contents ((self sequencer-track-control))
  (om-with-font 
   (om-make-font "Arial" 80 :style '(:bold))
   (om-with-fg-color (om-make-color 1 1 1 0.1)
     (om-draw-string (- (round (w self) 2) 20) (+ (round (h self) 2) 24) 
                     (number-to-string (num self))))))

(defmethod om-draw-contents ((self sequencer-track-view))
  (let* ((editor (editor (om-view-window self)))
         (maquette (object editor)))
    (when (get-g-component editor :metric-ruler) ;; just in case
     (om-with-fg-color (om-gray-color 0 0.1)
       (draw-grid self (get-g-component editor :metric-ruler))))
    (loop for tb in (get-track-boxes maquette (num self)) 
          when (and (> (+ (get-box-onset tb) (get-box-duration tb)) (x1 self))
                    (< (get-box-onset tb) (x2 self)))
          do
          (let ((x1 (x-to-pix self (get-box-onset tb)))
                (x2 (x-to-pix self (+ (get-box-onset tb) (get-box-duration tb)))))
            (draw-temporal-box tb self x1 0 (- x2 x1) (h self) (- (get-obj-time maquette) (get-box-onset tb)))
            (when (selected tb)
              (om-with-fg-color (om-make-color-alpha (om-def-color :gray) 0.5)
                (om-draw-rect x1 0 (- x2 x1) (h self) :fill t)))))))

(defmethod om-draw-contents-area ((self sequencer-track-view) x y w h)
  (let* ((editor (editor (om-view-window self)))
         (maquette (object editor))
         (xmax (+ x w))
         (t1 (pixel-to-time self x))
         (t2 (pixel-to-time self xmax))
         (ruler (get-g-component editor :metric-ruler)))
    
  
    ;;;MARKERS
    (when (and ruler (markers-p ruler))
      (loop for marker in (remove-if #'(lambda (mrk) (or (< mrk t1) (> mrk t2))) (get-all-time-markers ruler)) ;;;PAS OPTIMAL
            do 
            (let ((pos (time-to-pixel ruler marker)))
              (om-with-fg-color (om-make-color  0.9 0.7 0 (if (find marker (selected-time-markers ruler)) 1 0.45))
                (om-draw-line pos 0 pos (h self))))
            ))
    
    ;;;GRID
    (when ruler
     (om-with-fg-color (om-gray-color 0 0.1)
       (om-with-line '(2 2)
         (loop for beat in (remove-if #'(lambda (pt) (or (< (car pt) t1) (> (car pt) t2))) (point-list ruler))
               do 
               (draw-grid-line self ruler (ruler-value-to-pix ruler (car beat)))))))

    ;;;START CURSOR POS
    (let ((i1 (time-to-pixel self (car (cursor-interval ruler))))
          (i2 (time-to-pixel self (cadr (cursor-interval ruler)))))
      (om-with-fg-color (om-make-color 0.8 0.7 0.7)
        (om-with-line '(3 3) 
          (om-with-line-size 1
            (om-draw-line i1 0 i1 (h self))
            (om-draw-line i2 0 i2 (h self)))))
      (om-draw-rect i1 0 (- i2 i1) (h self) :fill t :color (om-make-color-alpha (om-def-color :white) 0.2)))
    
    ;;;CONTENT
    (loop for tb in (get-track-boxes maquette (num self))
          do
          (let ((x1 (x-to-pix self (get-box-onset tb)))
                (x2 (x-to-pix self (get-box-end-date tb))))
            (when (selected tb)
              (om-with-fg-color (om-make-color-alpha (om-def-color :black) 0.5)
                (om-draw-rect x1 0 (- x2 x1) (h self) :fill t)))
          (if (and (<= x1 xmax) (> x2 x))
              (draw-temporal-box tb self x1 0 (- x2 x1) (h self) (- (pix-to-x self x) (get-box-onset tb))))))
    
   
    ))


#|
;;;;;;;;========================================
;;;;;;;; TO EXTRACT CODE
;;;;;;;;========================================

(defmethod draw-maquette-mini-view ((object t) (box OMBox) x y w h &optional time)
  (ensure-cache-display-draw box object)
  (draw-mini-view object box x y w h time))

(defmethod draw-mini-view ((self bpf) (box t) x y w h &optional time)
  (let ((display-cache (get-display-draw box)))
    (draw-bpf-points-in-rect (cadr display-cache)
                             (color self) 
                             (car display-cache)
                             ;(+ x 7) (+ y 10) (- w 14) (- h 20)
                             x (+ y 10) w (- h 20)
                             )
    t))

(defun conversion-factor-and-offset (min max w delta)
  (let* ((range (- max min))
         (factor (if (zerop range) 1 (/ w range))))
    (values factor (- delta (* min factor)))))

(defun draw-bpf-points-in-rect (points color ranges x y w h)
  (multiple-value-bind (fx ox) 
      (conversion-factor-and-offset (car ranges) (cadr ranges) w x)
    (multiple-value-bind (fy oy) 
        ;;; Y ranges are reversed !! 
        (conversion-factor-and-offset (cadddr ranges) (caddr ranges) h y)
      (when points 
        (om-with-fg-color (om-def-color :gray)
        ;draw first point
        (om-draw-circle (+ ox (* fx (car (car points))))
                        (+ oy (* fy (cadr (car points))))
                        3 :fill t)
        (let ((lines (loop for pts on points
                           while (cadr pts)
                           append
                           (let ((p1 (car pts))
                                 (p2 (cadr pts)))
                             (om-draw-circle (+ ox (* fx (car p2)))
                                             (+ oy (* fy (cadr p2)))
                                             3 :fill t)
                             ;;; collect for lines 
                             (om+ 0.5
                                  (list (+ ox (* fx (car p1)))
                                        (+ oy (* fy (cadr p1)))
                                        (+ ox (* fx (car p2)))
                                        (+ oy (* fy (cadr p2)))))
                             ))))
          (om-with-fg-color (or color (om-def-color :dark-gray))
            (om-draw-lines lines))))))))

(defmethod draw-temporal-box ((self omboxeditcall) view x y w h &optional (time 0))
  (call-next-method)
  (case (display self)  
    (:mini-view (draw-maquette-mini-view (get-box-value self) self x y w h nil))
    (:text (draw-mini-text (get-box-value self) self x y w h nil))
    (:hidden  (om-with-font (om-def-font :font1 :face "arial" :size 18 :style '(:bold))
                          (om-with-fg-color (om-make-color 0.6 0.6 0.6 0.5)
                            (om-draw-string (+ x 10) (max 22 (+ 6 (/ h 2))) 
                                            (string-upcase (type-of (get-box-value self)))))))))


(defmethod draw-temporal-box ((self OMBox) view x y w h &optional (time 0))
  (when (color self)
    (om-with-fg-color (om-make-color-alpha (color self) 0.9)
      (om-draw-rect x y w h :fill t)))
  (om-with-fg-color (om-def-color :white)
    (om-draw-rect x y w h :fill nil))
  (om-with-fg-color (om-def-color :white)
    (om-draw-string (+ x 2) (+ y h -2) (number-to-string (get-box-onset self)))))
;;;;;;;;========================================
;;;;;;;;========================================
;;;;;;;;========================================
|#

(defmethod resizable-box? ((self OMBox)) t)
(defmethod resizable-box? ((self OMBoxEditCall)) nil)

(defmethod update-view-from-ruler ((self x-ruler-view) (view sequencer-track-view))
  (call-next-method)
  (setf (car (range (object (editor view)))) (x1 self)
        (cadr (range (object (editor view)))) (x2 self)))

(defmethod om-view-click-handler ((self sequencer-track-view) position)
  (let* ((editor (editor (om-view-window self)))
         (time (round (pix-to-x self (om-point-x position))))
         (selected-box (box-at-pos editor time (num self)))
         (p0 position))
   
    (editor-box-selection editor selected-box)
     
    (om-invalidate-view (om-view-window self))
    ;; (when selected-box (move-selection-in-track-action self editor selected-box position)) ;; ???
   
    (cond 
     (selected-box
      (let ((selected-end-time-x (time-to-pixel self (get-box-end-date selected-box))))
        (if (and (resizable-box? selected-box)
                 (<= (om-point-x position) selected-end-time-x) (>= (om-point-x position) (- selected-end-time-x 5)))
            ;;; resize the box
            (om-init-temp-graphics-motion 
             self position nil
             :motion #'(lambda (view pos)
                         (when (> (- (om-point-x pos) (x-to-pix self (get-box-onset selected-box))) 10)
                           (set-box-duration selected-box 
                                             (- (round (pix-to-x self (om-point-x pos)))
                                                (get-box-onset selected-box)))
                           (om-invalidate-view self)))
             :release #'(lambda (view pos) 
                          (report-modifications editor) 
                          (om-invalidate-view self))
             :min-move 4)
            ;;; move the selection
            (let ((copy? (when (om-option-key-p) (mapcar 'om-copy (get-selected-boxes editor))))
                  (init-tracks (mapcar 'group-id (get-selected-boxes editor))))
              (when copy?
                (select-unselect-all editor nil)
                (mapcar #'(lambda (b) 
                            (setf (group-id b) NIL)
                            (select-box b t))
                        copy?))
              (om-init-temp-graphics-motion 
               self position nil
               :motion #'(lambda (view pos)
                           (let ((dx (round (dpix-to-dx self (- (om-point-x pos) (om-point-x p0)))))
                                 (py (om-point-y pos)))
                     
                             (when copy?
                               (mapcar #'(lambda (b) 
                                           (unless (group-id b)
                                             (add-box-in-track (object editor) b (num self))
                                             (setf (frame b) self)))
                                       copy?))
                     
                             (let ((diff-track-id (floor py (h self))))
                               (loop for tb in (get-selected-boxes editor) 
                                     for init-track in init-tracks do 
                                     (let ((new-box-id (+ init-track diff-track-id)))
                                       (when (and (> new-box-id 0) (<= new-box-id (n-tracks editor)))
                                       (update-inspector-for-box tb) ;; here ?
                                       (setf (group-id tb) new-box-id)))))
                     
                             (move-editor-selection editor :dx dx)
                             (setf p0 pos)
                             (om-invalidate-view (om-view-window self))))
               :release #'(lambda (view pos) 
                            (report-modifications editor) 
                            (om-invalidate-view (om-view-window self)))
               :min-move 4)))
        ))
     ((om-add-key-down)
      (let ((box (new-box-in-maq-editor editor (omp time 100) (num self))))
        (setf (frame box) self)
        (om-set-view-cursor self (om-get-cursor :h-size))
        (om-init-temp-graphics-motion 
               self position nil
               :motion #'(lambda (view pos)
                           (when (> (- (om-point-x pos) (x-to-pix self (get-box-onset box))) 10)
                             (set-box-duration box 
                                               (- (round (pix-to-x self (om-point-x pos)))
                                                  (get-box-onset box)))
                           (om-invalidate-view self)))
               :release #'(lambda (view pos) 
                            (report-modifications editor)
                            (om-invalidate-view self))
               :min-move 4)
        (report-modifications editor)))
     (t (call-next-method))
     )))


(defmethod om-view-mouse-motion-handler :around ((self sequencer-track-view) position)
  (let ((mouse-x (om-point-x position))
        (end-times-x (mapcar 
                    #'(lambda (box) (time-to-pixel self (get-box-end-date box)))
                    (remove-if-not #'resizable-box? (get-track-boxes (object (editor (om-view-window self))) (num self))))))
    (if (find mouse-x end-times-x :test #'(lambda (a b) (and (<= a b) (>= a (- b 5)))))
        (om-set-view-cursor self (om-get-cursor :h-size))
      (progn (om-set-view-cursor self nil)
        (call-next-method)
        ))))


;; not used at the moment...
(defmethod move-selection-in-track-action ((self sequencer-track-view) editor orig-box position)
  (om-init-temp-graphics-motion 
   self position nil :min-move 4
   :motion #'(lambda (view pos)
               (let* ((dx (round (dpix-to-dx self (- (om-point-x pos) (om-point-x position)))))
                      (selected-box-onset (get-box-onset orig-box))
                      (snap-delta 200)
                      (new-dx (if (snap-to-grid editor) 
                                  (adapt-dt-for-grid-and-markers (get-g-component editor :metric-ruler) selected-box-onset dx snap-delta)
                                dx)))
                 (when (not (equal new-dx 0))
                   (setf position pos)
                   (move-editor-selection editor :dx new-dx)
                   (update-to-editor editor self)
                   )))
   :release #'(lambda (view pos) 
                (report-modifications editor) 
                (update-to-editor editor self))))


(defmethod om-view-doubleclick-handler ((self sequencer-track-view) position)
  (let* ((editor (editor (om-view-window self)))
         (time (pix-to-x self (om-point-x position)))
         (selected-box (box-at-pos editor time (num self))))
    (if selected-box 
        (open-editor selected-box)
      (progn
        (set-player-interval editor (list time time))
        (set-object-time (get-obj-to-play editor) time)))))


(defmethod om-drag-receive ((self sequencer-track-view) (dragged-view OMBoxFrame) position &optional (effect nil))
   (let ((editor (editor (om-view-window self)))
         (dragged-obj (object dragged-view)))
     (when (allowed-element (object editor) dragged-obj) ; (get-box-value dragged-obj)
       (let ((new-box (om-copy dragged-obj)))
         (setf (box-x new-box) (round (pix-to-x self (om-point-x position)))
               (box-y new-box) 0 (box-h new-box) 10)
         (add-box-in-track (object editor) new-box (num self))
         (setf (frame new-box) self)
         (update-to-editor editor self)
         t))))

;;;===============================
;;; DISPLAY BOXES IN MAQUETTE TRACKS
;;;===============================

;;; to be redefined by objects if they have a specific miniview for the maquette
(defmethod draw-maquette-mini-view ((object t) (box OMBox) x y w h &optional time)
  (ensure-cache-display-draw box object)
  (draw-mini-view object box x y w h time))

(defmethod draw-temporal-box ((self OMBox) view x y w h &optional (time 0))
  (when (color self)
    (om-with-fg-color (om-make-color-alpha (color self) 0.9)
      (om-draw-rect x y w h :fill t)))
  (om-with-fg-color (om-def-color :white)
    (om-draw-rect x y w h :fill nil))
  (om-with-fg-color (om-def-color :white)
    (om-draw-string (+ x 2) (+ y h -2) (number-to-string (get-box-onset self)))))
    
(defmethod draw-temporal-box ((self OMBoxPatch) view x y w h &optional (time 0))
  (call-next-method)
  (case (display self)  
    (:mini-view (draw-maquette-mini-view (reference self) self x y w h time))
    (:value 
     (om-with-clip-rect view x y w h
     (draw-maquette-mini-view (get-box-value self) self x y 
                              (if (get-box-value self)
                                  (dx-to-dpix view (get-obj-dur (get-box-value self)))
                                w)
                              h time)
     (om-draw-picture (icon (reference self)) :x (+ x 4) :y (+ y 4) :w 16 :h 16)))
    (:hidden  (om-with-font (om-def-font :font1 :face "arial" :size 18 :style '(:bold))
                            (om-with-fg-color (om-make-color 0.6 0.6 0.6 0.5)
                              (om-draw-string (+ x (/ w 2) -6) (max 22 (+ 6 (/ h 2))) "P")))))
  (when (find-if 'reactive (outputs self))
    (om-draw-rect x y w h :line 2 :color (om-def-color :dark-red)))
  
  (if (plusp (pre-delay self))
      (om-with-fg-color (om-def-color :red)
        (om-draw-circle (- x (dx-to-dpix view (pre-delay self))) (/ h 2) 3 :fill t)
        (om-draw-dashed-line x (/ h 2) 
                             (- x (dx-to-dpix view (pre-delay self))) (/ h 2)))))

(defmethod draw-temporal-box ((self omboxeditcall) view x y w h &optional (time 0))
  (call-next-method)
  (case (display self)  
    (:mini-view (draw-maquette-mini-view (get-box-value self) self x y w h time))
    (:text (draw-mini-text (get-box-value self) self x y w h nil))
    (:hidden  (om-with-font (om-def-font :font1 :face "arial" :size 18 :style '(:bold))
                          (om-with-fg-color (om-make-color 0.6 0.6 0.6 0.5)
                            (om-draw-string (+ x 10) (max 22 (+ 6 (/ h 2))) 
                                            (string-upcase (type-of (get-box-value self)))))))))


;;; !! this is a special case : the frame of the object must change
;;; + the 'update' reference of the inspector window (= self) becomes the wrong one
;;; 1 solution = re-create the inspector if thrack is changed
;;; other solution = invalidate all tracks all the time
(defmethod update-view ((self sequencer-track-view) (object OMBox))
  (let ((editor (editor (om-view-window self))))
    ;;; sets the right frame for the box
    (unless (and (frame object) (equal (num (frame object)) (group-id object)))
      (setf (frame object) (find (group-id object) (get-g-component editor :track-views) :key 'num :test '=)))
    (mapcar 'om-invalidate-view (get-g-component editor :track-views))))

;;;========================
;;; KEYBOARD ACTIONS
;;;========================

(defmethod editor-key-action ((editor maquette-editor) key)
  (let ((maquette (object editor)))
    (case key
      (:om-key-left
       (move-editor-selection editor :dx (- (get-units (get-g-component editor :metric-ruler) (if (om-shift-key-p) 100 10))))
       (om-invalidate-view (window editor))
       (report-modifications editor))
      (:om-key-right
       (move-editor-selection editor :dx (get-units (get-g-component editor :metric-ruler) (if (om-shift-key-p) 100 10)))
       (om-invalidate-view (window editor))
       (report-modifications editor))
      (#\v (with-schedulable-object maquette
                                    (loop for tb in (get-selected-boxes editor) do 
                                          (eval-box tb)
                                          (reset-cache-display tb)
                                          (contextual-update tb maquette)))
           (om-invalidate-view (window editor))
           (report-modifications editor))
      (#\r (loop for tb in (get-selected-boxes editor) do (set-reactive tb (not (all-reactive-p tb))))
           (om-invalidate-view (window editor)))
      (otherwise 
       (call-next-method)
       (om-invalidate-view (window editor)))
      )))


(defmethod show-inspector-window ((self maquette-editor))
  (let ((selection (append (get-selected-boxes self)
                           (get-selected-connections self))))
    (if (= 1 (length selection))
        (let ((obj (car selection)))
          (show-inspector obj (get-my-view-for-update (frame obj))))
      (om-beep-msg "Wrong selection for inspector..."))))

;;;========================
;;; TIME MARKERS
;;;========================

;TIME MARKERS : method to redefine by subclasses
;(defmethod get-timed-objects-for-graduated-view ((self sequencer-track-view))
;  "returns a list of timed-object to retrieve their markers"
;  (mapcar 'get-box-value (nth (num self) (tracks (get-obj-to-play (editor self))))))

(defmethod get-timed-objects-for-graduated-view ((self sequencer-track-view))
  "returns a list of timed-object to retrieve their markers"
  (get-track-boxes (get-obj-to-play (editor self)) (num self)))

;TIME MARKERS method to redefine by subclasses
(defmethod select-elements-at-time ((self sequencer-track-view) marker-time)
  "selects the elements with same time than the marker-time"
   (let* ((editor (editor (om-view-window self)))
          (box (box-at-pos editor marker-time (num self))))
     (when box (select-box box t))
     (update-to-editor editor self)))

;;==============================
;; MARKER API SPECIAL MAQUETTE
;;==============================

(defmethod translate-elements-from-time-marker ((self OMBox) elems dt)
  "translates elements from a time marker with dt"
  (when (get-box-value self)
    (with-schedulable-object (container self)
                             (translate-elements-from-time-marker (get-box-value self) elems dt))
    (reset-cache-display self)
    (contextual-update self (container self))))

(defmethod get-elements-for-marker ((self OMBox) marker)
  "returns a list of elements matching the marker"
  (when (get-box-value self)
    (get-elements-for-marker (get-box-value self) marker)))

(defmethod get-time-markers ((self OMBox))
  "returns a list of time markers"
  (when (and (get-box-value self) (show-markers self))
    (get-time-markers (get-box-value self))))



;;;========================
;;; PLAYER
;;;========================

(defmethod play-editor-callback ((self maquette-editor) time)
  (let ((t-auto (get-tempo-automation self)))
    (set-time-display self time)
    (mapcar #'(lambda (view) (when view (update-cursor view time))) (cursor-panes self))
    ;(if (not (getf (beat-info self) :next-date))
    ;    (setf (getf (beat-info self) :next-date) (get-beat-date t-auto (getf (beat-info self) :beat-count))))
    ;(loop while (>= time (getf (beat-info self) :next-date))
    ;      do
    ;      (om-set-dialog-item-text (cadr (om-subviews (tempo-box self))) (format nil "~$" (tempo-at-beat t-auto (getf (beat-info self) :beat-count))))
    ;      (incf (getf (beat-info self) :beat-count) 0.1)
    ;      (setf (getf (beat-info self) :next-date) (get-beat-date t-auto (getf (beat-info self) :beat-count))))
    ))

(defmethod stop-editor-callback ((self maquette-editor))
  (setf (getf (beat-info self) :beat-count) 0
        (getf (beat-info self) :next-date) nil)
  (om-set-dialog-item-text (cadr (om-subviews (tempo-box self))) (format nil "~$" (tempo-at-beat (get-tempo-automation self) 0)))
  (call-next-method))


(defmethod get-interval-to-play ((self maquette-editor))
  (let ((sb (get-selected-boxes self)))
    (if sb
        (list (reduce 'min sb :key 'get-box-onset)
              (reduce 'max sb :key 'get-box-end-date))
      (call-next-method))))

;;;========================
;;; GENERAL CONSTRUCTOR
;;;========================

(defmethod make-editor-window-contents ((editor maquette-editor))
  (let* ((maquette (get-obj-to-play editor))
         (tracks-or-maq-view (if (equal (view-mode editor) :maquette)
                                 (make-maquette-view editor)
                               (make-tracks-view editor)))
         (nav-view (om-make-view 'om-view :bg-color (om-make-color (/ 215 256) (/ 215 256) (/ 215 256)) :scrollbars nil))
         (patch-view (om-make-layout 
                      'om-row-layout
                      :subviews 
                      (list 
                       (om-make-view 'om-view :bg-color (om-make-color (/ 215 256) (/ 215 256) (/ 215 256))) 
                       :divider 
                       (om-make-view 'om-view :bg-color (om-make-color (/ 215 256) (/ 215 256) (/ 215 256))))))
         (ctrl-view (om-make-view 
                     'om-view 
                     :direct-draw nil
                     :scrollbars :nil
                     :size (om-make-point nil 20)
                     :bg-color +track-color-2+
                     :subviews (list
                                (om-make-layout 
                                 'om-simple-layout :position (om-make-point 2 4)
                                 :subviews (list (make-time-monitor editor :color (om-def-color :white) :format t)))
                                (om-make-layout
                                 'om-row-layout :delta 30 :position (om-make-point (+ *track-control-w* 2) 2) :align :bottom
                                 :ratios '(1 1 100 1 1)
                                 :subviews (list
                                            (om-make-layout
                                             'om-row-layout 
                                             :delta 5 
                                             :position (om-make-point (+ *track-control-w* 2) 2)
                                             :align :bottom
                                             :size (om-make-point 90 15)
                                             :subviews (list ;(make-signature-box editor :bg-color +track-color-2+ :rulers (list ruler-tracks))
                                                        (make-tempo-box editor :bg-color +track-color-2+)))
                                            (om-make-layout
                                             'om-row-layout 
                                             :delta 5 
                                             :position (om-make-point (+ *track-control-w* 2) 2)
                                             :size (om-make-point 90 15)
                                             :subviews (list (make-play-button editor :enable t) 
                                                             (make-pause-button editor :enable t) 
                                                             (make-stop-button editor :enable t)
                                                             (make-previous-button editor :enable t) 
                                                             (make-next-button editor :enable t) 
                                                             (make-repeat-button editor :enable t)))
                                            nil
                                            (om-make-layout
                                             'om-row-layout 
                                             :delta 5 
                                             :subviews (let (b1 b2)
                                                         (setq b1 (om-make-graphic-object 
                                                                   'om-icon-button :size (omp 16 16) 
                                                                   :icon 'icon-maqview-black :icon-disabled 'icon-maqview-gray
                                                                   :lock-push nil :enabled (equal (view-mode editor) :tracks)
                                                                   :action #'(lambda (b) 
                                                                               (unless (equal (view-mode editor) :maquette)
                                                                                 (disable b) (enable b2)
                                                                                 (setf (view-mode editor) :maquette)
                                                                                 (init-window (window editor) editor))
                                                                               )))
                                                         (setq b2 (om-make-graphic-object 
                                                                   'om-icon-button :size (omp 16 16) 
                                                                   :icon 'icon-trackview-black :icon-disabled 'icon-trackview-gray
                                                                   :lock-push nil :enabled (equal (view-mode editor) :maquette)
                                                                   :action #'(lambda (b) 
                                                                               (unless (equal (view-mode editor) :tracks)
                                                                                 (disable b) (enable b1)
                                                                                 (setf (view-mode editor) :tracks)
                                                                                 (init-window (window editor) editor))
                                                                               )))
                                                         (list b1 b2)))
                                                        
                                            (om-make-layout
                                             'om-row-layout 
                                             :delta 5 
                                             :subviews (let (b1 b2 b3 b4)
                                                         (setq b1 (om-make-graphic-object 
                                                                   'om-icon-button :size (omp 16 16) 
                                                                   :icon 'ctrlpatch-black :icon-pushed 'ctrlpatch-gray
                                                                   :lock-push nil :enabled t
                                                                   :action #'(lambda (b)
                                                                               (open-editor (ctrlpatch (object editor))))))
                                                         (setq b2 (om-make-graphic-object 
                                                                   'om-icon-button :size (omp 16 16) 
                                                                   :icon 'maqeval-black :icon-pushed 'maqeval-gray
                                                                   :lock-push nil :enabled t
                                                                   :action #'(lambda (b)
                                                                               (let ((maq (get-obj-to-play editor)))
                                                                                 (loop for box in (get-all-boxes maq)
                                                                                      ;when (not (all-reactive-p box))
                                                                                       do
                                                                                       (progn
                                                                                         (eval-box box) 
                                                                                         (reset-cache-display box)
                                                                                         (contextual-update box maq)
                                                                                         (om-invalidate-view patch-view)))
                                                                                 (mapcar #'(lambda (i) (setf (defval i) maq)) (inputs (ctrlpatch maq)))
                                                                                 ;(setf (defval (car (inputs (ctrlpatch maq)))) maq)
                                                                                 ;(compile-patch (ctrlpatch maq))
                                                                                 ;(apply (intern (string (compiled-fun-name (ctrlpatch maq))) :om)
                                                                                 ;       `(,maq))
                                                                                 (mapcar 'eval-box (get-boxes-of-type (ctrlpatch maq) 'omoutbox))
                                                                                 (om-invalidate-view tracks-or-maq-view)
                                                                                 ))))
                                                         (setq b3 (om-make-graphic-object 
                                                                   'om-icon-button :size (omp 16 16) 
                                                                   :icon 'icon-trash-black :icon-pushed 'icon-trash-gray
                                                                   :lock-push nil :enabled t
                                                                   :action #'(lambda (b) 
                                                                               (when (om-y-or-n-dialog "Do you really want to remove all boxes in the maquette?")
                                                                                 (m-flush (get-obj-to-play editor))
                                                                                 (om-invalidate-view tracks-or-maq-view)
                                                                                 ))))
                                                         (setq b4 (om-make-graphic-object 
                                                                   'om-icon-button :size (omp 16 16) 
                                                                   :icon 'icon-no-exec-black :icon-pushed 'icon-no-exec-gray
                                                                   :lock-push t :enabled t
                                                                   :action #'(lambda (b)
                                                                               (with-schedulable-object maquette
                                                                                                        (setf (no-exec maquette) 
                                                                                                              (not (no-exec maquette)))))))
                                                         (list b1 b2 b3 b4)))))))))
         
    (set-g-component editor :patch-view patch-view)
    (set-g-component editor :nav-view nav-view)
    (set-g-component editor :ctrl-view ctrl-view)
  
    (om-make-layout 
     'om-row-layout :delta 2 :ratios '(1 nil 100)
     :subviews (list 
                ;;; LEFT PART
                nav-view :divider
                ;;; REST (RIGHT)
                (om-make-layout 
                 'om-column-layout :delta nil :ratios '(1 98 nil 1)
                 :subviews (list 
                            ctrl-view 
                            tracks-or-maq-view
                            :divider 
                            patch-view))))))


(defun make-maquette-view (maq-editor)
  (let* ((ruler-maquette (om-make-view 'time-ruler 
                                       :size (om-make-point 30 20)
                                       :x1 (car (get-range maq-editor)) 
                                       :x2 (cadr (get-range maq-editor))
                                       :scrollbars nil :bg-color +track-color-1+))
         (metric-ruler (om-make-view 'metric-ruler 
                                     :size (om-make-point 30 20)
                                     :scrollbars nil :bg-color +track-color-1+))
         (maq-view (om-make-view 'maquette-view :editor maq-editor :scrollbars t :bg-color +track-color-1+))
         layout)
    (set-g-component maq-editor :track-views nil)
    (set-g-component maq-editor :maq-view maq-view)
    (set-g-component maq-editor :metric-ruler metric-ruler)
    (set-g-component maq-editor :abs-ruler ruler-maquette)
    
    (attach-view-to-ruler ruler-maquette metric-ruler)
    (attach-view-to-ruler metric-ruler ruler-maquette)
    (attach-view-to-ruler metric-ruler maq-view)
    
    (update-span metric-ruler)
    
    (setf layout (om-make-layout 
                  'om-grid-layout
                  :delta 2 :dimensions '(2 3) :ratios '((1 99) (1 99 1))
                  :subviews
                  (list
                   (om-make-di 'om-simple-text 
                               :size (om-make-point *track-control-w* 20) 
                               :text "metric"; (non-linear)"
                               :font (om-def-font :font1) 
                               :fg-color (om-def-color :black)
                               :bg-color +track-color-2+)
                   metric-ruler
                   (om-make-view 'om-view :bg-color +track-color-1+)
                   maq-view
                   (om-make-di 'om-simple-text 
                               :size (om-make-point *track-control-w* 20) 
                               :text "absolute"; (linear)"
                               :font (om-def-font :font1) 
                               :fg-color (om-def-color :black)
                               :bg-color +track-color-2+)
                   ruler-maquette)))
    (put-patch-boxes-in-editor-view (object maq-editor) maq-view)
    layout
    ))


(defun make-track-control (n editor)
  (let ((f-color +font-color+))

#|
    (om-make-view 
     'sequencer-track-control :num n
     :size (om-make-point *track-control-w* *track-h*)
     :bg-color (nth (mod n 2) (list +track-color-1+ +track-color-2+))
     :subviews (let ((ypos 2) (delta 2) (slider-h 14) 
                     panval volval
                     (font1 (om-def-font :font1)) (font2 (om-def-font :font1b))
                     (mainbgcolor +maq-bg-color+))
                 (list
                  (om-make-di 'om-simple-text
                              :text (format nil "Track ~A" n) :fg-color f-color :font font2
                              :position (om-make-point (- (round *track-control-w* 2) 22) (* 2 delta))
                              :size (om-make-point 50 16))
                  (om-make-di 'om-slider
                              :position (om-make-point 10 (incf ypos (+ 18 delta)))
                              :size (om-make-point (- *track-control-w* 10) nil)
                              :range '(-50 50) :value 0 :increment 1
                              :direction :horizontal :tick-side :none
                              :di-action #'(lambda (item)
                                             (let ((val (om-slider-value item)))
                                               (set-track-pan (get-obj-to-play editor) n val)
                                               (om-set-dialog-item-text 
                                                panval  
                                                (cond ((< val 0) (format nil "~DL" (abs val)))
                                                      ((> val 0) (format nil "~DR" val))
                                                      ((= val 0) (format nil "C")))))))
                  (om-make-di 'om-simple-text
                              :fg-color f-color :font font1 :text "Pan"
                              :position (om-make-point 5 (incf ypos (+ slider-h delta)))
                              :size (om-make-point 90 nil))
                  (setq panval (om-make-di 'om-simple-text
                                           :fg-color f-color :font font1 :text "C"
                                           :position (om-make-point (- *track-control-w* 45) ypos)
                                           :size (om-make-point 90 (progn (incf ypos 16) 16))))
                  ;(om-make-di 'om-slider
                  ;            :position (om-make-point 10 (1+ ypos))
                  ;            :size (om-make-point (- *track-control-w* 10) (progn (incf ypos (+ slider-h delta)) slider-h))
                  ;            :range '(0 100) :value 100 :increment 1
                  ;            :direction :horizontal :tick-side :none
                  ;            :di-action #'(lambda (item) 
                  ;                           (om-set-dialog-item-text
                  ;                            volval 
                  ;                            (format nil "~1$" 
                  ;                                    (let ((dbval (* 20 (log (/ (max 0.001 (om-slider-value item)) 100)))))
                  ;                                      (if (>= dbval -92.1) dbval "-inf"))))))
                  (om-make-di 'om-slider
                              :position (om-make-point 10 (1+ ypos))
                              :size (om-make-point (- *track-control-w* 10) (progn (incf ypos (+ slider-h delta)) slider-h))
                              :range '(0 200) :value 100 :increment 1
                              :direction :horizontal :tick-side :none
                              :di-action #'(lambda (item)
                                             (let ((gain (/ (om-slider-value item) 100.0)))
                                               (set-track-gain (get-obj-to-play editor) n gain)
                                               (om-set-dialog-item-text 
                                                volval 
                                                (format nil "~1$" gain)))))
                  (om-make-di 'om-simple-text 
                              :fg-color f-color :font font1 :text "Gain"
                              :position (om-make-point 5 ypos)
                              :size (om-make-point 90 16))
                  (setq volval (om-make-di 'om-multi-text
                                           :fg-color f-color :font font1 :text "0.0"
                                           :position (om-make-point (- *track-control-w* 45) (+ 2 ypos))
                                           :size (om-make-point 90 (progn (incf ypos 16) 16)))))))
|#    
    (om-make-view 
     'sequencer-track-control :num n
     :size (om-make-point *track-control-w* *track-h*)
     :bg-color (nth (mod n 2) (list +track-color-1+ +track-color-2+)))))


(defun make-tracks-view (maq-editor)
  (let* ((ruler-tracks (om-make-view 'time-ruler :size (om-make-point 30 20) 
                                     :x1 (car (get-range maq-editor)) 
                                     :x2 (cadr (get-range maq-editor))
                                     :scrollbars nil :bg-color +track-color-1+
                                     :bottom-p nil :markers-p t))
         (track-views (loop for n from 1 to (n-tracks maq-editor) collect
                            (om-make-view 'sequencer-track-view :num n :size (omp nil *track-h*)
                                          :scrollbars :h :editor maq-editor
                                          :bg-color (nth (mod n 2) (list +track-color-1+ +track-color-2+)))))
         (metric-ruler (om-make-view 'metric-ruler 
                                      :size (om-make-point 30 20)
                                      :scrollbars nil :bg-color +track-color-1+
                                      :markers-p t)))  ;;; enable/disable markers here

    (set-g-component maq-editor :track-views track-views)
    (set-g-component maq-editor :maq-view nil)
    (set-g-component maq-editor :metric-ruler metric-ruler)
    (set-g-component maq-editor :abs-ruler ruler-tracks)
    (attach-view-to-ruler ruler-tracks metric-ruler)
    (attach-view-to-ruler metric-ruler ruler-tracks)
    (mapcar #'(lambda (v) (attach-view-to-ruler ruler-tracks v)) track-views)
    (mapcar #'(lambda (v) (attach-view-to-ruler metric-ruler v)) track-views)
    
    (update-span metric-ruler)
    
    ;;; set the track view as 'frame' for each box
    (loop for track-view in track-views do 
          (loop for box in (get-track-boxes (object maq-editor) (num track-view)) do
                (setf (frame box) track-view)))
    
    (om-make-layout 
     'om-column-layout :delta 2 :ratios '(1 99 1)
     :subviews (list 
                ;;; the ruler bar
                (om-make-layout 
                 'om-row-layout :delta 2 :ratios '(1 99)
                 :subviews (list (om-make-di 'om-simple-text 
                                             :size (om-make-point *track-control-w* 20) 
                                             :text "metric"; (non-linear)"
                                             :font (om-def-font :font1) 
                                             :fg-color (om-def-color :black)
                                             :bg-color +track-color-2+)
                                 metric-ruler))
                ;;; allows to scroll he sub-layout
                (om-make-layout 
                 'om-simple-layout :subviews 
                 (list 
                  (om-make-layout 
                   'om-column-layout :delta 2 :scrollbars :v
                   :subviews
                   (loop for n from 1 to (n-tracks maq-editor) collect 
                         (om-make-layout 
                          'om-row-layout :delta 2 :ratios '(1 99)
                          :subviews (list 
                                     (make-track-control n maq-editor)
                                     (nth (1- n) track-views)))))))
                (om-make-layout 
                 'om-row-layout :delta 2 :ratios '(1 99)
                 :subviews (list (om-make-di 'om-simple-text 
                                             :size (om-make-point *track-control-w* 20) 
                                             :text "absolute"; (linear)"
                                             :font (om-def-font :font1) 
                                             :fg-color (om-def-color :black)
                                             :bg-color +track-color-2+)
                                 ruler-tracks))))))


;;;=====================
;;; PLAYER INTERFACE
;;;=====================
(defmethod editor-make-player ((self maquette-editor))
  (make-player :reactive-player;:dynamic-scheduler
               :run-callback 'play-editor-callback
               :stop-callback 'stop-editor-callback))

(defmethod editor-repeat ((self maquette-editor) t-or-nil)
  (if t-or-nil
      (loop-object (get-obj-to-play self))
    (unloop-object (get-obj-to-play self))))

(defmethod editor-next-step ((self maquette-editor))
  (let* ((object (get-obj-to-play self))
         (step (get-units (cadr (cursor-panes self))))
         (time (get-obj-time object)))
    (set-object-time object (+ step (- time (mod time step))))
    (set-object-time (metronome self) (+ step (- time (mod time step))))))

(defmethod editor-previous-step ((self maquette-editor))
  (let* ((object (get-obj-to-play self))
         (step (get-units (cadr (cursor-panes self))))
         (time (get-obj-time object)))
    (set-object-time object (max 0 (- (- time (mod time step)) step)))
    (set-object-time (metronome self) (max 0 (- (- time (mod time step)) step)))))

(defmethod editor-close ((self maquette-editor))
  (player-stop-object (player self) (metronome self))
  (call-next-method))

#|

;;; Future Box (Box maker selection rectangle)
(defclass future-box (selection-rectangle) ())

(defmethod om-draw-contents ((self future-box))
  (let ((x (if (plusp (w self)) 0 -2))
        (y (if (plusp (h self)) 0 -2))
        (w (- (w self) (if (plusp (w self)) 1 -4)))
        (h (- (h self) (if (plusp (h self)) 1 -4))))
    (om-draw-rect x y w h :fill t :color (om-make-color 0.5 0.5 0.5 0.7))
    (om-with-fg-color (om-make-color 0.6 0.2 0.2 0.7)
      (om-with-line-size 2
        (om-with-line '(4 4)
          (om-draw-rect x y w h)))
      (om-with-font (om-def-font :font4b)
                    (om-draw-string w h "+")))))

(defmethod om-view-click-handler ((self maquette-view) pos)
  (let ((p0 pos))
    (if (and (om-command-key-p))
        (om-init-temp-graphics-motion self pos 
                                      (om-make-graphic-object 'future-box :position pos :size (om-make-point 4 4)
                                                              :fg-color (om-def-color :green))

                                      :release #'(lambda (view position)
                                                   (print (list (om-point-x p0) (om-point-y p0)
                                                                (om-point-x position) (om-point-y position)))))
      (call-next-method))))
|#



