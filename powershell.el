;; powershell.el, version 0.1
;;
;; Author: Dino Chiesa
;; Thu, 10 Apr 2008  11:10
;;
;; Run Windows PowerShell v1.0 as an inferior shell within emacs. Tested with emacs v22.2.
;;
;; TODO:
;;  test what happens when you expand the window size beyond the maxWindowWidth for the RawUI
;;  make everything configurable (Powershell exe, initial args, powershell prompt regexp)
;;  implement powershell launch hooks
;;  prevent backspace from deleting the powershell prompt? (do other shells do this?)
;;

(require 'shell)


(defun powershell-gen-window-width-string ()
  (concat  "$a = (Get-Host).UI.RawUI\n"
            "$b = $a.WindowSize\n"
            "$b.Width = " (number-to-string  (window-width)) "\n"
            "$a.BufferSize = $b\n"
            "$a.WindowSize = $b")
  )


(defvar powershell-prompt-pattern  "PS [^#$%>]+>"
  "Regexp for powershell prompt.  This isn't really used, because I couldn't figure out how to get it to work."
  )

(defgroup powershell nil
  "Running shell from within Emacs buffers."
  :group 'processes
  )


(defcustom powershell-need-rawui-resize t
  "set when powershell needs to be resized"
  :group 'powershell
)

;;;###autoload
(defun powershell (&optional buffer)
  "Run an inferior powershell, by invoking the shell function. See the help for shell for more details.
\(Type \\[describe-mode] in the shell buffer for a list of commands.)"
  (interactive
   (list
    (and current-prefix-arg
         (read-buffer "Shell buffer: "
                      (generate-new-buffer-name "*PowerShell*")))))
  ; get a name for the buffer
  (setq buffer (get-buffer-create (or buffer "*PowerShell*")))

  (let (
        (tmp-shellfile explicit-shell-file-name)
        )
                                        ; set arguments for the powershell exe.
                                        ; This needs to be tunable.
    (setq explicit-shell-file-name "c:\\windows\\system32\\WindowsPowerShell\\v1.0\\powershell.exe")
    (setq explicit-powershell.exe-args '("-Command" "-" )) ; interactive, but no command prompt

                                        ; launch the shell
    (shell buffer)

    ; restore the original shell
    (if explicit-shell-file-name
        (setq explicit-shell-file-name tmp-shellfile)
      )
    )

  (let (
        (proc (get-buffer-process buffer))
        )

    ; This sets up the powershell RawUI screen width. By default,
    ; the powershell v1.0 assumes terminal width of 80 chars.
    ;This means input gets wrapped at the 80th column.  We reset the
    ; width of the PS terminal to the window width.
    (add-hook 'window-size-change-functions 'powershell-window-size-changed)

    (powershell-window-size-changed)

    ; ask for initial prompt
    (comint-simple-send proc "prompt")
    )

  ; hook the kill-buffer action so we can kill the inferior process?
  (add-hook 'kill-buffer-hook 'powershell-delete-process)

  ; wrap the comint-input-sender with a PS version
  ; must do this after launching the shell!
  (make-local-variable 'comint-input-sender)
  (setq comint-input-sender 'powershell-simple-send)

  ; set a preoutput filter for powershell.  This will trim newlines after the prompt.
  (add-hook 'comint-preoutput-filter-functions 'powershell-preoutput-filter-for-prompt)

  ;(run-hooks 'powershell-launch-hook)

  ; return the buffer created
  buffer
)


(defun powershell-window-size-changed (&optional frame)
  ; do not actually resize here. instead just set a flag.
  (setq powershell-need-rawui-resize t)
)



(defun powershell-delete-process (&optional proc)
  (or proc
      (setq proc (get-buffer-process (current-buffer))))
  (and (processp proc)
       (delete-process proc))
  )



;; This function trims the newline from the prompt that we
;; get back from powershell.  It is set into the preoutput
;; filters, so the newline is trimmed before being put into
;; the output buffer.
(defun powershell-preoutput-filter-for-prompt (string)
   (if
       ; not sure why, but I have not succeeded in using a variable here???
       ;(string-match  powershell-prompt-pattern  string)

       (string-match  "PS [^#$%>]+>" string)
       (substring string 0 -1)

     string

     )
   )



(defun powershell-simple-send (proc string)
  "Override of the comint-simple-send function, specific for powershell.
This just sends STRING, plus the prompt command. Normally powershell is in
noninteractive model when run as an inferior shell with stdin/stdout
redirected, which is the case when running as a shell within emacs.
This function insures we get and display the prompt. "
  ; resize if necessary. We do this by sending a resize string to the shell,
  ; before sending the actual command to the shell.
  (if powershell-need-rawui-resize
      (and
       (comint-simple-send proc (powershell-gen-window-width-string))
       (setq powershell-need-rawui-resize nil)
       )
    )
  (comint-simple-send proc string)
  (comint-simple-send proc "prompt")
)
