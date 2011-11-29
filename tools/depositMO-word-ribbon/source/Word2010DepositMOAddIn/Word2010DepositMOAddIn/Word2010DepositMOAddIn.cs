/*
   Copyright 2011 University of Southampton

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

using System.Collections.Generic;
using Word = Microsoft.Office.Interop.Word;
using Core = Microsoft.Office.Core;
using Microsoft.Office.Tools;
using System.Diagnostics;
using System;
using System.Windows.Forms;

namespace uk.ac.soton.ses.Word2010DepositMOAddIn
{
    /// <summary>
    /// Entry point for the Microsoft Word 2010 DepositMO add-in
    /// </summary>
    public partial class Word2010DepositMOAddIn
    {
        #region Default endpoint fields and accessors
        /// <summary>
        /// The default endpoint for new controls (could be "")
        /// </summary>
        private string defaultEndpoint = "http://depositmo.eprints.org/id/contents";

        /// <summary>
        /// The default username for new controls (could be "")
        /// </summary>
        private string defaultUsername = "";

        /// <summary>
        /// The default password for new controls (could be "")
        /// </summary>
        private string defaultPassword = "";

        /// <summary>
        /// Gets or sets the default endpoint
        /// </summary>
        internal string DefaultEndpoint { get { return this.defaultEndpoint; } set { this.defaultEndpoint = value; } }

        /// <summary>
        /// Gets or sets the default username
        /// </summary>
        internal string DefaultUsername { get { return this.defaultUsername; } set { this.defaultUsername = value; } }

        /// <summary>
        /// Gets or sets the default password
        /// </summary>
        internal string DefaultPassword { get { return this.defaultPassword; } set { this.defaultPassword = value; } }
        #endregion

        /// <summary>
        /// A list of all the repository controls the addin deals with
        /// </summary>
        internal List<DepositMORepositoryControl> repositoryControls = new List<DepositMORepositoryControl>();

        /// <summary>
        /// Gets the properties of the active document
        /// </summary>
        /// <returns></returns>
        internal Core.DocumentProperties GetActiveDocumentProperties()
        {
            return (Core.DocumentProperties)Globals.Word2010DepositMOAddIn.Application.ActiveDocument.BuiltInDocumentProperties;
        }

        #region Submission thread counters
        /// <summary>
        /// Lock object for threading
        /// </summary>
        private static readonly object lockobj = new object();

        /// <summary>
        /// The number of active submission threads
        /// </summary>
        private uint submissionThreadCounter = 0;

        /// <summary>
        /// Gets the number of active submission threads
        /// </summary>
        internal uint SubmissionThreadCount { get { return this.submissionThreadCounter; } }

        /// <summary>
        /// Increments the thread count
        /// </summary>
        internal void IncrementSubmissionThreadCount()
        {
            lock (lockobj)
            {
                this.submissionThreadCounter++;
                this.LogMessage(this.GetActiveSubmissionString());
            }
        }

        /// <summary>
        /// Decrements the thread count
        /// </summary>
        internal void DecrementSubmissionThreadCount()
        {
            lock (lockobj)
            {
                this.submissionThreadCounter--;
                this.LogMessage(this.GetActiveSubmissionString());
            }
        }

        /// <summary>
        /// Returns a formatted string containing the current pending submission summary
        /// </summary>
        /// <returns></returns>
        private string GetActiveSubmissionString()
        {
            return String.Format("{0} submission{1} currently active", this.SubmissionThreadCount, (this.SubmissionThreadCount == 1) ? "" : "s");
        }

        #endregion

        #region Internal logging
        /// <summary>
        /// Maximum number of lines to store in the internal log buffer
        /// </summary>
        private static int MAX_LOG_LINES = 32 * 1024;

        /// <summary>
        /// Number of lines by which to reduce the log buffer if <code>MAX_LOG_LINES</code> is reached.
        /// Note this should be less than <code>MAX_LOG_LINES</code>.
        /// </summary>
        private static int PURGE_NUMBER_OF_LOG_LINES = 1 * 1024;

        /// <summary>
        /// Internal log buffer
        /// </summary>
        private List<String> log = new List<string>();

        /// <summary>
        /// Logs the message <code>message</code> to Word's status bar, any debug tracers
        /// and the log string list on this instance
        /// </summary>
        /// <param name="message">The log message</param>
        internal void LogMessage(string message)
        {
            Globals.Word2010DepositMOAddIn.Application.StatusBar = message;
            Debug.WriteLine(message);
            this.AddMessageToLogStack(message);
        }

        /// <summary>
        /// Adds the message to the log stack, and purges the log stack if the
        /// size exceeds the maximum
        /// </summary>
        /// <param name="message">Message to log</param>
        private void AddMessageToLogStack(string message)
        {
            this.log.Add(message);
            if (this.log.Count > MAX_LOG_LINES)
            {
                this.log.RemoveRange(0, PURGE_NUMBER_OF_LOG_LINES);
            }
        }

        /// <summary>
        /// Returns the log stack as a string array
        /// </summary>
        /// <returns>String array of log messages</returns>
        internal string[] GetAllLogMessages()
        {
            /// TODO: add some size management here
            return this.log.ToArray();
        }

        /// <summary>
        /// Sets the value of <code>textBox</code> to <code>text</code>, in
        /// a thread-safe manner.
        /// </summary>
        /// <param name="text">The target value for <code>textBox</code></param>
        /// <param name="textBox">The text box form control to set</param>
        internal void SetSingleLineTextBox(string text, TextBox textBox)
        {
            if (textBox.InvokeRequired)
            {
                SetTextCallback tc = new SetTextCallback(SetSingleLineTextBox);
                textBox.Invoke(tc, new Object[] { text, textBox });
            }
            else
            {
                textBox.Text = text;
            }
        }

        /// <summary>
        /// Text set callback delegate for <code>textBox</code>. Needed for invocation
        /// by thread-safe text box value updater
        /// </summary>
        /// <param name="message"></param>
        /// <param name="textBox"></param>
        delegate void SetTextCallback(string message, TextBox textBox);

        /// <summary>
        /// Logs the message to the internal stack, debug output (if appropriate)
        /// and the supplied text box. Thread-safe
        /// </summary>
        /// <param name="message">The message to log</param>
        /// <param name="textBox">The text box to which to log</param>
        internal void LogMessage(string message, TextBox textBox)
        {
            if (textBox.InvokeRequired)
            {
                SetTextCallback tc = new SetTextCallback(LogMessage);
                textBox.Invoke(tc, new Object[] { message, textBox });
            }
            else
            {
                if (textBox != null && !textBox.Disposing && !textBox.IsDisposed)
                {
                    textBox.AppendText(message + Environment.NewLine);
                }

                // call the regular logger only if the invoke isn't required to
                // avoid multiple messages appearing in the other logs
                this.LogMessage(message);
            }
        }
        #endregion

        /// <summary>
        /// For every task pane that can be made invisible, make it invisible.
        /// </summary>
        internal void MakeAllInvisible()
        {
            foreach (CustomTaskPane c in this.CustomTaskPanes)
            {
                if (c != null)
                {
                    c.Visible = false;
                }
            }
        }

        /// <summary>
        /// Makes each available task pane and any child controls visible, and
        /// shows the associated control. Also cleans up task panes where the
        /// child control is null.
        /// </summary>
        internal void MakeAllVisible()
        {
            // make all of the custom task panes visible, along with their controls
            foreach (CustomTaskPane c in this.CustomTaskPanes)
            {
                if (c != null)
                {
                    c.Visible = true;
                    if (c.Control != null)
                    {
                        c.Control.Show();
                        c.Control.Visible = true;
                    }
                    else
                    {
                        // the control itself is null, so dispose of the pane
                        c.Dispose();
                    }
                }
            }
            // ensure the repository controls are also visible
            foreach (DepositMORepositoryControl dmrc in this.repositoryControls)
            {               
                dmrc.Visible = true;
                dmrc.Show();
            }            
        }

        /// <summary>
        /// Called when the plug-in is started
        /// </summary>
        /// <param name="sender">Sender</param>
        /// <param name="e">Event arguments</param>
        private void ThisAddIn_Startup(object sender, System.EventArgs e)
        {
            // when the addin is started, create a new repository control
            // and place an event to repeat this when a document is opened
            this.AddRepositoryControl();
            
            // no independent event handler for a new document, only [new|open|focus] or [open]
            //this.Application.DocumentOpen += new Word.ApplicationEvents4_DocumentOpenEventHandler(Application_DocumentOpen);
            this.Application.DocumentChange += new Word.ApplicationEvents4_DocumentChangeEventHandler(AddRepositoryControl);

            // log version and timestamp for diagnostics
            this.LogMessage("Started " + System.Reflection.Assembly.GetExecutingAssembly().FullName + " at " + DateTime.Now);            
        }
        
        /// <summary>
        /// Adds a new repository control panel to the list and
        /// adds it to the custom task panes group
        /// </summary>
        private void AddRepositoryControl()
        {         
            if (this.Application.Documents.Count == 0)
            {
                // COM will throw an exception if we try to do anything with ActiveWindow (even a test for null)
                // if there are no open documents
                return;
            }

            foreach (CustomTaskPane ctp in this.CustomTaskPanes)
            {
                if (ctp != null && ctp.Window != null && ctp.Control != null && !ctp.Control.Disposing && ctp.Window == this.Application.ActiveWindow)
                {
                    // we already have a control for this task pane so don't continue to add a new one
                    return;
                }
            }        
            
            // create a new repository control, add it to the internal list and add it to
            // a custom task pane associated with this document window
            DepositMORepositoryControl dmrc = new DepositMORepositoryControl();
            this.repositoryControls.Add(dmrc);
            this.CustomTaskPanes.Add(dmrc, "Repository control", this.Application.ActiveWindow);            
        }

        /// <summary>
        /// Event method to be called when a document is opened (or created, or focus switched, the
        /// latter of which is handled by the repository control add method
        /// </summary>
        /// <param name="Doc">The associated Word document</param>
        void Application_DocumentOpen(Word.Document Doc)
        {
            // add a new repository control when a new document has been created
            // (not ideal, but Word will otherwise end up with multiple panels per document)
            this.AddRepositoryControl();                       
        }   

        /// <summary>
        /// Event triggered when the add-in is shut down. Note that we will wait briefly for threads to clean
        /// up here, but this will 'lock' Word when the user tries to close if a submission is in
        /// limbo (and causing Task Manager-level 'force quits'). As at this point the user won't have
        /// received a 'successfully submitted' message, and there's no guarantee that the document
        /// has been submitted. Word itself will terminate the threads after a short while
        /// </summary>
        /// <param name="sender">Sender object</param>
        /// <param name="e">Event arguments</param>
        private void ThisAddIn_Shutdown(object sender, System.EventArgs e)
        {
            string statusText = "Shutting down DepositMO plugin";
            if (this.SubmissionThreadCount > 0)
            {
                statusText += String.Format("; {0} - you will have to check these manually", this.GetActiveSubmissionString());
            }
            this.Application.StatusBar = statusText;
        }

        #region VSTO generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InternalStartup()
        {
            this.Startup += new System.EventHandler(ThisAddIn_Startup);
            this.Shutdown += new System.EventHandler(ThisAddIn_Shutdown);
        }
        
        #endregion
    }
}
