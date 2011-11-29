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
using System.Linq;
using System.Text;
using Microsoft.Office.Tools.Ribbon;

namespace uk.ac.soton.ses.Word2010DepositMOAddIn
{
    /// <summary>
    /// Ribbon interface for Microsoft Word 2010 DepositMO add-in
    /// </summary>
    public partial class Word2010DepositMORibbon
    {
        internal string quickUsername = null;
        internal string quickPassword = null;

        /// <summary>
        /// Event triggered when the ribbon is loaded
        /// </summary>
        /// <param name="sender">Event sender</param>
        /// <param name="e">Event arguments</param>
        private void Word2010DepositMORibbon_Load(object sender, RibbonUIEventArgs e)
        {            
            this.endpointEditBox.Text = Globals.Word2010DepositMOAddIn.DefaultEndpoint;
            this.quickSubmissionRibbonGroup.DialogLauncherClick += new RibbonControlEventHandler(quickSubmissionRibbonGroup_DialogLauncherClick);
            this.Word2010DepositMOMainGroup.DialogLauncherClick += new RibbonControlEventHandler(Word2010DepositMOMainGroup_DialogLauncherClick);
        }

        /// <summary>
        /// Event triggered when the first group's dialogue launcher is selected (bottom-right miniature icon).
        /// Brings up the log viewer
        /// </summary>
        /// <param name="sender">Event sender</param>
        /// <param name="e">Event arguments</param>
        void Word2010DepositMOMainGroup_DialogLauncherClick(object sender, RibbonControlEventArgs e)
        {            
            LogViewerForm lvf = new LogViewerForm();
            lvf.Show();
        }

        /// <summary>
        /// Event triggered when the quick submission dialogue launcher is selected (bottom-right miniature icon).
        /// Brings up the quick submission form
        /// </summary>
        /// <param name="sender">Event sender</param>
        /// <param name="e">Event arguments</param>
        void quickSubmissionRibbonGroup_DialogLauncherClick(object sender, RibbonControlEventArgs e)
        {
            QuickSubmitForm qsf = new QuickSubmitForm();
            // this really can't find the parent window!
            qsf.ShowDialog((System.Windows.Forms.IWin32Window)Globals.Ribbons.GetRibbon<Word2010DepositMORibbon>().Container);         
        }

        /// <summary>
        /// Event triggered when the show panel button is clicked
        /// </summary>
        /// <param name="sender">Event sender</param>
        /// <param name="e">Event arguments</param>
        private void Word2010DepositMORepositoryButton_Click(object sender, RibbonControlEventArgs e)
        {
            Globals.Word2010DepositMOAddIn.MakeAllVisible();
        }

        /// <summary>
        /// Event triggered when the hide panel button is clicked
        /// </summary>
        /// <param name="sender">Event sender</param>
        /// <param name="e">Event arguments</param>
        private void Word2010DepositMORepositoryHideButton_Click(object sender, RibbonControlEventArgs e)
        {
            Globals.Word2010DepositMOAddIn.MakeAllInvisible();
        }

        /// <summary>
        /// Event triggered when the quick submit button is clicked
        /// </summary>
        /// <param name="sender">Event sender</param>
        /// <param name="e">Event arguments</param>
        private void quickSubmitButton_Click(object sender, RibbonControlEventArgs e)
        {
            this.quickSubmissionRibbonGroup_DialogLauncherClick(sender, e);
        }

        /// <summary>
        /// Event triggered when the about button is clicked. Launches the about box
        /// </summary>
        /// <param name="sender">Event sender</param>
        /// <param name="e">Event arguments</param>
        private void aboutRibbonButton_Click(object sender, RibbonControlEventArgs e)
        {
            AboutBox aboutBox = new AboutBox();
            aboutBox.ShowDialog((System.Windows.Forms.IWin32Window)Globals.Ribbons.GetRibbon<Word2010DepositMORibbon>().Container);            
        }       
    }
}
