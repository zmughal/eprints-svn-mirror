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
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using Microsoft.Office.Tools;

namespace uk.ac.soton.ses.Word2010DepositMOAddIn
{
    /// <summary>
    /// Quick submission form for the Microsoft Word 2010 DepositMO add-in
    /// </summary>
    public partial class QuickSubmitForm : Form
    {
        /// <summary>
        /// Constructor for quick submission Windows form
        /// </summary>
        public QuickSubmitForm()
        {
            InitializeComponent();
            this.repositoryLocationTextBox.Text = Globals.Ribbons.GetRibbon<Word2010DepositMORibbon>().endpointEditBox.Text;

            if (!String.IsNullOrEmpty(Globals.Ribbons.GetRibbon<Word2010DepositMORibbon>().quickUsername))
            {
                this.usernameTextBox.Text = Globals.Ribbons.GetRibbon<Word2010DepositMORibbon>().quickUsername;
            }

            if (!String.IsNullOrEmpty(Globals.Ribbons.GetRibbon<Word2010DepositMORibbon>().quickPassword))
            {
                this.passwordTextBox.Text = Globals.Ribbons.GetRibbon<Word2010DepositMORibbon>().quickPassword;
            }
        }

        private void cancelButton_Click(object sender, EventArgs e)
        {
            this.Close();
            this.Dispose();
        }

        private void submitButton_Click(object sender, EventArgs e)
        {
            CustomTaskPaneCollection ctps = Globals.Word2010DepositMOAddIn.CustomTaskPanes;
            if (ctps.Count == 0)
            {
                // abort
                this.Close();
                this.Dispose();
                return;
            }

            CustomTaskPane currentTaskPane = null;

            foreach (CustomTaskPane ctp in ctps)
            {           
                if (ctp.Window == Globals.Word2010DepositMOAddIn.Application.ActiveWindow)
                {
                    currentTaskPane = ctp;
                }                
            }

            if (currentTaskPane == null)
            {
                // abort
                MessageBox.Show("Could not get the correct task pane");
                this.Close();
                this.Dispose();
                return;
            }
            
            if(currentTaskPane.Control is DepositMORepositoryControl)            
            {
                DepositMORepositoryControl dmrControl = (DepositMORepositoryControl)currentTaskPane.Control;                
                dmrControl.SubmitDocument(false, this.usernameTextBox.Text, this.passwordTextBox.Text, this.repositoryLocationTextBox.Text);
            }
            else
            {
                MessageBox.Show("Couldn't get control over the repository panel");
            }

            // update the internal fields on the ribbon if applicable

            if (!String.IsNullOrEmpty(this.usernameTextBox.Text))
            {
                Globals.Ribbons.GetRibbon<Word2010DepositMORibbon>().quickUsername = this.usernameTextBox.Text;
            }

            if (!String.IsNullOrEmpty(this.passwordTextBox.Text))
            {
                Globals.Ribbons.GetRibbon<Word2010DepositMORibbon>().quickPassword = this.passwordTextBox.Text;
            }

            this.Close();
            this.Dispose();
        }
    }
}
