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

namespace uk.ac.soton.ses.Word2010DepositMOAddIn
{
    /// <summary>
    /// Internal log viewer for Microsoft Word 2010 DepositMO add-in
    /// </summary>
    public partial class LogViewerForm : Form
    {
        /// <summary>
        /// Windows form for viewing the log
        /// </summary>
        public LogViewerForm()
        {
            InitializeComponent();
            // set the contents of the text box to be the singleton's log message stack       
            this.logTextBox.Lines = Globals.Word2010DepositMOAddIn.GetAllLogMessages();           
        }

        /// <summary>
        /// Event triggered by clicking the log viewer's close button
        /// </summary>
        /// <param name="sender">Event sender</param>
        /// <param name="e">Event arguments</param>
        private void closeButton_Click(object sender, EventArgs e)
        {
            this.Close();
            this.Dispose();
        }

        /// <summary>
        /// Copies the contents of the log text box to the clipboard
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void copyButton_Click(object sender, EventArgs e)
        {
            Clipboard.SetText(this.logTextBox.Text);
        }
    }
}
