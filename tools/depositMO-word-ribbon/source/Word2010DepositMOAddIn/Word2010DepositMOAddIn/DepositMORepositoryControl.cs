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

using System;
using System.Windows.Forms;
using Microsoft.Office.Interop.Word;
using System.IO;
using System.Xml;
using System.Threading;
using System.Runtime.InteropServices;

/// Namespace for Microsoft Word 2010 DepositMO add-in
namespace uk.ac.soton.ses.Word2010DepositMOAddIn
{
    /// <summary>
    /// Custom Windows Forms user control for Microsoft Word 2010 DepositMO add-in
    /// </summary>
    public partial class DepositMORepositoryControl : UserControl
    {
        /// <summary>
        /// The username for the repository at the endpoint
        /// </summary>
        internal string username { get { return this.usernameTextBox.Text; } }

        /// <summary>
        /// The password for the repository
        /// </summary>
        internal string password { get { return this.passwordTextBox.Text; } }

        /// <summary>
        /// The repository's endpoint
        /// </summary>
        internal string endpoint { get { return this.repositoryLocationTextBox.Text; } }

        /// <summary>
        /// Lock object for threading
        /// </summary>
        private static readonly object lockobj = new object();

        /// <summary>
        /// Constructor. Sets the default endpoint, username and password
        /// </summary>
        public DepositMORepositoryControl()
        {         
            InitializeComponent();
            this.repositoryLocationTextBox.Text = Globals.Word2010DepositMOAddIn.DefaultEndpoint;
            this.usernameTextBox.Text = Globals.Word2010DepositMOAddIn.DefaultUsername;
            this.passwordTextBox.Text = Globals.Word2010DepositMOAddIn.DefaultPassword;
        }

        /// <summary>
        /// OnLoad handler; adds tooltips        
        /// </summary>
        /// <param name="sender">Event sender</param>
        /// <param name="e">Event parameters</param>
        private void DepositMORepositoryControl_Load(object sender, EventArgs e)
        {
            new ToolTip().SetToolTip(this.addToGroupButton, "Add these repository details to the group to submit documents en masse");
            new ToolTip().SetToolTip(this.documentLocationTextBox, "The location of the document");
            new ToolTip().SetToolTip(this.passwordTextBox, "The password of the user at the repository");
            new ToolTip().SetToolTip(this.usernameTextBox, "The username of the user at the repository");
            new ToolTip().SetToolTip(this.removeFromGroupButton, "Removes the selected repository's details from the group");
            new ToolTip().SetToolTip(this.repositoryLocationTextBox, "The location (endpoint) of the repository");
            new ToolTip().SetToolTip(this.submitToAllButton, "Submits the current document to all endpoints in the group, using the credentials specific to each repository");
            new ToolTip().SetToolTip(this.submissionLogTextBox, "Information about the submissions (successes, failures, counts and so on)");
            new ToolTip().SetToolTip(this.submitToThisRepositoryButton, "Submits the current document to the specified endpoint");
            new ToolTip().SetToolTip(this.updateEprintButton, "Updates the document at the specified endpoint");
        }

        /// <summary>
        /// Event handler for clicking the submit to this repository button
        /// </summary>
        /// <param name="sender">Event sender</param>
        /// <param name="e">Event arguments</param>
        private void submitToThisRepositoryButton_Click(object sender, EventArgs e)
        {
            this.SubmitDocument(false); 
        }

        /// <summary>
        /// Submits the document to the endpoint. If <code>updateExisting</code> is true,
        /// then the endpoint will be taken to be that in the document location text area,
        /// otherwise the general repository endpoint will be used
        /// </summary>
        /// <param name="updateExisting"></param>
        private void SubmitDocument(bool updateExisting)
        {
            string documentEndpoint = this.endpoint;
            if (updateExisting)
            {
                documentEndpoint = this.documentLocationTextBox.Text;
            }
            this.SubmitDocument(updateExisting, this.username, this.password, documentEndpoint); //this.endpoint);
        }

        /// <summary>
        /// Logs the supplied message to the submission log text box and the global log message stack
        /// </summary>
        /// <param name="message">The message to log</param>
        private void logMessage(string message)
        {
            Globals.Word2010DepositMOAddIn.LogMessage(message, this.submissionLogTextBox);
        }

        /// <summary>
        /// Fires the document submission on a separate thread to avoid locking Word's UI whilst the
        /// deposition is being negotiated. The thread is issued via a delegate to provide the 
        /// underlying submission method (<code>_SubmitDocument</code>) with multiple parameters
        /// </summary>
        /// <param name="updateExisting"><code>true</code> if the endpoint represents an existing document, 
        /// else <code>false</code> for a new submission</param>
        /// <param name="username">The username for the repository at <code>endpoint</code></param>
        /// <param name="password">The password associated with <code>username</code></param>
        /// <param name="endpoint">The endpoint against which submission should occur</param>
        internal void SubmitDocument(bool updateExisting, string username, string password, string endpoint)
        {                        
            Thread submitThread = new Thread(() => this._SubmitDocument(updateExisting, username, password, endpoint));
            submitThread.Start();                        
        }

        /// <summary>
        /// Submits the document to the target endpoint, or updates the document at the target endpoint
        /// using the supplied credentials.
        /// </summary>
        /// <param name="updateExisting"><code>true</code> to update an existing document, else <code>false</code></param>
        /// <param name="username">The username of the user at the repository</param>
        /// <param name="password">The password of the user at the repository</param>
        /// <param name="endpoint">The endpoint of the repository</param>
        /// <returns></returns>
        private bool _SubmitDocument(bool updateExisting, string username, string password, string endpoint)
        {
            // we might not technically have come in on a new thread but to keep things consistent we'll
            // increment the counter here, and decrement it at every handled exit point of the method
            Globals.Word2010DepositMOAddIn.IncrementSubmissionThreadCount();

            #region Pre-submission checks
            // pre-submission checks
            if (String.IsNullOrWhiteSpace(endpoint))
            {
                this.WarningBox("Attempting to submit document to empty endpoint; cowardly refusing to continue");
                Globals.Word2010DepositMOAddIn.DecrementSubmissionThreadCount();
                return false;
            }
            #endregion

            // grab a reference to the active document outside the lock so if someone
            // changes the active document whilst another thread is active it will
            // be the correct document
            Document d = Globals.Word2010DepositMOAddIn.Application.ActiveDocument;
            
            // ensure the user has saved their document before continuing (see
            // read-lock comments below)
            try
            {
                d.Save();
            }
            catch
            {
                // for some reason the standard flow control of Word means that
                // if the user cancels the save dialogue, an exception will be thrown
                // --- this is contrary to standard Windows Forms behaviour                
                this.WarningBox("Didn't save the document this time; deposition aborted");
                Globals.Word2010DepositMOAddIn.DecrementSubmissionThreadCount();
                return false;
            }
            
            // this could be spun off on a separate (singleton-type) thread
            // to avoid UI glitches if the remote isn't responding quickly 
            lock (lockobj)
            {                
                SwordClientHandler sch = null;                                
                string originalDocumentName = null;
                string tempFileName = null;
                bool updateResult = false;

                // get the full path and filename of the document and remember this
                originalDocumentName = d.FullName;

                // save the file to the temporary path
                tempFileName += Path.GetTempPath() + d.Name;

                try
                {
                    // we need to 'save as' under a different filename as Word has an exclusive
                    // read-lock on the current document; 'Type.Missing' through the call until
                    // we can set the 'add to recent files' flag to false
                    d.SaveAs2(tempFileName, Type.Missing, Type.Missing, Type.Missing, false);

                    // we then need to 'save as' the original filename to restore the control
                    // to the user
                    d.SaveAs2(originalDocumentName);
                }
                catch (COMException cex)
                {                    
                    this.logMessage("A problem occurred with " + cex.Source + " whilst trying to save the document");
                    this.logException(cex);
                    this.logMessage("Couldn't submit document " + originalDocumentName + " this time as " + cex.Source + " will not allow it");                    
                    Globals.Word2010DepositMOAddIn.DecrementSubmissionThreadCount();
                    return false;
                }

                // initialise the SWORD handler
                this.logMessage("Connecting to repository at " + endpoint);
                sch = new SwordClientHandler(username, password, endpoint);

                // use the PUT parts of SWORD if we're updating
                if (updateExisting)
                {
                    // 'endpoint' in this context should now be the location of the document
                    #region Update existing document
                    try { updateResult = sch.PutToDocument(tempFileName, endpoint); }
                    catch (Exception ex)
                    {
                        this.logMessage("Could not update document at " + endpoint);
                        this.logException(ex);
                    }
                    finally { File.Delete(tempFileName); }

                    if (updateResult)
                    {
                        this.logMessage("Successfully updated document at " + endpoint);
                        Globals.Word2010DepositMOAddIn.DecrementSubmissionThreadCount();
                        return true;
                    }
                    else
                    {
                        this.logMessage("Couldn't update document at " + endpoint);
                        Globals.Word2010DepositMOAddIn.DecrementSubmissionThreadCount();
                        return false;
                    }
                    #endregion
                }
                else
                {
                    #region Create new document
                    // create new document
                    string documentUri = null;
                    
                    try { documentUri = sch.PostDocxToRepository(tempFileName); }
                    catch (Exception ex)
                    {
                        this.logMessage("Could not deposit document to " + endpoint);
                        this.logException(ex);
                    }
                    finally { File.Delete(tempFileName); }
                    #endregion

                    // check for null response. Behaviour at this point is undefined
                    if (documentUri == null)
                    {
                        this.logMessage("Couldn't understand response from server at endpoint " + endpoint + "; please check deposition manually");
                        Globals.Word2010DepositMOAddIn.DecrementSubmissionThreadCount();
                        return false;
                    }

                    #region Response handling on new deposition
                    // attempt to parse the response
                    if (!String.IsNullOrEmpty(documentUri))
                    {
                        this.logMessage("Document deposited at " + documentUri);
                        Globals.Word2010DepositMOAddIn.SetSingleLineTextBox(documentUri, this.documentLocationTextBox);
                    }
                    else
                    {
                        this.logMessage("Warning: response from endpoint " + endpoint + " did not contain a reference to the submitted document");
                        Globals.Word2010DepositMOAddIn.DecrementSubmissionThreadCount();
                        return false;
                    }
                    Globals.Word2010DepositMOAddIn.DecrementSubmissionThreadCount();
                    return true;
                    #endregion
                }
                
            }            
        }

        /// <summary>
        /// Logs the exception <code>ex</code> to the global log
        /// </summary>
        /// <param name="ex">Exception to log</param>
        private void logException(Exception ex)
        {
            this.logMessage("Full error was: " + ex.ToString());
            this.logMessage("Please contact your administrator or report this if you believe it to be a bug");
        }

        /// <summary>
        /// Dumps the user's repository contents to the log
        /// </summary>
        private void DumpListingToLog()
        {
            this.DumpListingToLog(this.username, this.password, this.endpoint);
        }

        /// <summary>
        /// Dumps the user's repository contents to the log
        /// </summary>
        /// <param name="username">Repository username</param>
        /// <param name="password">Repository password</param>
        /// <param name="endpoint">Repository endpoint</param>
        private void DumpListingToLog(string username, string password, string endpoint)
        {
            SwordClientHandler sch = new SwordClientHandler(username, password, endpoint);
            XmlDocument recordsXml = sch.ListRecords(true);
            if (recordsXml != null)
            {
                SwordListReader slr = new SwordListReader(recordsXml);
                foreach (SwordListEntry sle in slr.Entries)
                {
                    this.logMessage(sle.Title + " [ " + sle.Updated.ToLocalTime().ToLongDateString() + "]");
                }
            }
        }

        /// <summary>
        /// Event handler for the update ePrint button
        /// </summary>
        /// <param name="sender">Event sender</param>
        /// <param name="e">Event arguments</param>
        private void updateEprintButton_Click(object sender, EventArgs e)
        {
            if (this.documentLocationTextBox.Text == String.Empty || this.documentLocationTextBox.Text == "")
            {
                //this.logMessage("No document location provided; refusing to update");
                this.WarningBox("No document location has been provided against which to update. Perhaps you meant to submit rather than update?");
            }
            else
            {
                this.SubmitDocument(true);
            }
        }

        /// <summary>
        /// Displays a warning dialogue box with the message <code>message</code>
        /// </summary>
        /// <param name="message">The message to display</param>
        private void WarningBox(string message)
        {
            MessageBox.Show(message, "DepositMO", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            this.logMessage(message);
        }

        /// <summary>
        /// Adds a repository to the group
        /// </summary>
        /// <param name="username">The username of the user at the repository</param>
        /// <param name="password">The password of the user at the repository</param>
        /// <param name="endpoint">The endpoint of the repository</param>
        private void addRepository(string username, string password, string endpoint)
        {
            // get a unique number for this session so we can grab a handle back to it later
            int high_id = 0;
            foreach (TabPage t in this.repositoryCollectionTabControl.TabPages)
            {
                int tabvalue = int.Parse(t.Text);
                if (tabvalue > high_id)
                {
                    high_id = tabvalue;
                }
            }
            int id = high_id + 1;
            string idstring = id.ToString();

            // create a new repository control
            RepositoryGroupUserControl rguc = new RepositoryGroupUserControl();
            rguc.Name = idstring;
            rguc.id = id;
            rguc.username = username;
            rguc.password = password;
            rguc.endpoint = endpoint;

            // create a new tab page with the ID...
            TabPage tp = new TabPage(idstring);

            // ... add the repository control to the page ...
            tp.Controls.Add(rguc);

            // ... and add it to the tab control
            this.repositoryCollectionTabControl.TabPages.Add(tp);
            this.logMessage("Added repository " + rguc.endpoint + " to collection with ID " + idstring);
        }

        /// <summary>
        /// Event handler when the add to group button has been clicked
        /// </summary>
        /// <param name="sender">Event sender</param>
        /// <param name="e">Event arguments</param>
        private void addToGroupButton_Click(object sender, EventArgs e)
        {
            this.addRepository(this.username, this.password, this.endpoint);
        }

        /// <summary>
        /// Removes the currently selected tab page from the tab control. Note that
        /// at the moment we don't do anything with the repository control underneath (GC?)
        /// </summary>
        /// <param name="sender">Event sender</param>
        /// <param name="e">Event arguments</param>
        private void removeFromGroupButton_Click(object sender, EventArgs e)
        {
            if (this.repositoryCollectionTabControl.SelectedTab != null)
            {
                this.repositoryCollectionTabControl.TabPages.Remove(this.repositoryCollectionTabControl.SelectedTab);
            }                
        }

        /// <summary>
        /// Click event handler for submit to all repositories
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void submitToAllButton_Click(object sender, EventArgs e)
        {
            this.submitToAll();
        }

        /// <summary>
        /// Iterates across all the tab pages, takes the repository/username/password triples
        /// from there and attempts to submit the document to each repository
        /// </summary>
        private void submitToAll()
        {
            int submissionCount = 0;
            foreach (TabPage tabPage in this.repositoryCollectionTabControl.TabPages)
            {
                RepositoryGroupUserControl rguc = (RepositoryGroupUserControl)tabPage.Controls[0];
                this.SubmitDocument(false, rguc.username, rguc.password, rguc.endpoint);
                submissionCount++;
            }
            this.logMessage("Submitted document to " + submissionCount.ToString() + " repositories");
        }
    }
}
