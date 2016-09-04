
(in-package :om)

;;;============================
;;; OSC BUNDLE OBJECT
;;;============================
(defclass* osc-bundle (data-frame)
  ((date :accessor date :initarg :date :initform 0 :documentation "time of the frame")
   (messages :accessor messages :initarg :messages :initform nil :documentation "list of osc messages")))

;(defmethod om-init-instance ((self osc-bundle) args)
;  (let* ((pointer-in (find-value-in-kv-list args :bundle-pointer))
;         (data-in (find-value-in-kv-list args :messages))
;         (tt-in (find-value-in-kv-list args :date)))
;    (when pointer-in
;      (when data-in 
;        (update-bundle-pointer-data pointer-in data-in))
;      (when tt-in 
;        (update-bundle-pointer-timetag pointer-in tt-in)))
;    self))

(defmethod initialize-instance :after ((self osc-bundle) &rest args)
  (unless (and (listp (messages self))
               (listp (car (messages self))))
    (setf (messages self) (list messages self))))

(defmethod data-size ((self osc-bundle))
  (length (flat (messages self))))

(defmethod* osc-send ((self osc-bundle) host port)
  (osc-send (messages self) host port))

(defmethod get-frame-action ((self osc-bundle))
  #'(lambda () (osc-send self "localhost" 3000)))


(defmethod osc-msg (address data)
  (cons (if (stringp address) address (format nil "~A" address))
        (if (listp data) data (list data))))

(defmethod osc-msg (address (data textbuffer))
  (osc-msg address (textbuffer-read data :text)))


;(defun format-message (message &optional (indent 0))
;  (if (stringp (car message))
;      (list (concatenate 'string 
;                   (make-sequence 'string (* indent 4) :initial-element #\Tab)
;                   (car message) " "
;                   (format nil "~A" (cdr message))))
;    (loop for sub in message append 
;          (format-message sub (1+ indent)))
;    ))

(defun format-message (message &optional (indent 0))
  (let ((tab (make-sequence 'string (* indent 4) :initial-element #\Space)))
  (append 
   (list (concatenate 'string tab (car message) " [ "))
   (loop for arg in (cdr message) append (format-argument arg (1+ indent)))
   (list (concatenate 'string tab " ] "))
   )))

;;; simpler: just on 1 line
(defun format-message (message &optional (indent 0))
  (format nil "~{~a~^ ~}" message))

(defmethod format-argument (arg indent) 
  (let ((tab (make-sequence 'string (* indent 4) :initial-element #\Space)))
    (list (concatenate 'string tab (format nil "~A" arg)))))

(defmethod format-argument ((arg list) indent) 
  (loop for msg in arg collect (format-message msg indent)))

(defmethod get-text-description ((self osc-bundle))
  (cons "OSC BUNDLE" 
        (flat (mapcar 'format-message (messages self))))
  )

(defmethod display-modes-for-object ((self osc-bundle))
  '(:hidden :text :mini-view))

(defmethod draw-mini-view ((self osc-bundle) (box t) x y w h &optional time)
  (let ((display-cache (ensure-cache-display-text box self)))
    (om-draw-rect x y w h :fill t :color (om-gray-color 0.48))
    (om-with-fg-color (om-def-color :white)
    (om-with-font (om-def-font :font1)
    ;;(flat (mapcar 'format-message (messages self))) 
    (loop for msg in (cadr (cadr display-cache))
          for yy = 20 then (+ yy 12) while (< yy h) do
          (om-draw-string 6 yy (format nil "~{~a~^ ~}" msg))
          )))))


(defun find-osc-values (osc-bundle address)
  (cdr (find address (messages osc-bundle) :test 'string-equal :key 'car)))


(defmethod compute-frame-color ((self osc-bundle) editor) 
  (declare (ignore editor))
  (let ((colorvals (find-osc-values self "/color")))
    (if colorvals (apply 'om-make-color colorvals)
      (call-next-method))))

(defmethod compute-frame-posy ((self osc-bundle) editor) 
  (declare (ignore editor))
  (or (car (find-osc-values self "/y")) (call-next-method)))

(defmethod compute-frame-sizey ((self osc-bundle) editor) 
  (declare (ignore editor))
  (or (car (find-osc-values self "/size")) (call-next-method)))


;;;======================================
;;; TEMP: GENERATE RANDOM BUNDLES
;;;======================================
(defun gen-bundles (n)
  (and n
       (sort 
        (loop for i from 1 to n collect 
              (make-instance 'osc-bundle 
                             :date (om-random 0.0 60000.0)
                             :messages (loop for i from 0 to (random 6) append
                                             (list (list "/foo/b/c" (random 20) (random 20.0) (random 20.0))
                                                   (list "/without/nested/bundle" 
                                                    (random 60.0)
                                                    ;(loop for i from 0 to (random 3) collect 
                                                    ;      (list "/control/a" (random 20)))
                                                    )))
                             ))
        '< :key 'date)))


