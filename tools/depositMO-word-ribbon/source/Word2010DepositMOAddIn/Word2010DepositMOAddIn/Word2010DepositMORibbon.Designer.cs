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

namespace uk.ac.soton.ses.Word2010DepositMOAddIn
{
    partial class Word2010DepositMORibbon : Microsoft.Office.Tools.Ribbon.RibbonBase
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// The constructor for the DepositMO Word ribbon
        /// </summary>
        public Word2010DepositMORibbon()
            : base(Globals.Factory.GetRibbonFactory())
        {
            InitializeComponent();
        }

        /// <summary> 
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Component Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            Microsoft.Office.Tools.Ribbon.RibbonDialogLauncher ribbonDialogLauncherImpl1 = this.Factory.CreateRibbonDialogLauncher();
            Microsoft.Office.Tools.Ribbon.RibbonDialogLauncher ribbonDialogLauncherImpl2 = this.Factory.CreateRibbonDialogLauncher();
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(Word2010DepositMORibbon));
            this.tab1 = this.Factory.CreateRibbonTab();
            this.Word2010DepositMORibbonTab = this.Factory.CreateRibbonTab();
            this.Word2010DepositMOMainGroup = this.Factory.CreateRibbonGroup();
            this.Word2010DepositMORepositoryButton = this.Factory.CreateRibbonButton();
            this.Word2010DepositMORepositoryHideButton = this.Factory.CreateRibbonButton();
            this.quickSubmissionRibbonGroup = this.Factory.CreateRibbonGroup();
            this.endpointEditBox = this.Factory.CreateRibbonEditBox();
            this.quickSubmitButton = this.Factory.CreateRibbonButton();
            this.aboutRibbonGroup = this.Factory.CreateRibbonGroup();
            this.aboutRibbonButton = this.Factory.CreateRibbonButton();
            this.tab1.SuspendLayout();
            this.Word2010DepositMORibbonTab.SuspendLayout();
            this.Word2010DepositMOMainGroup.SuspendLayout();
            this.quickSubmissionRibbonGroup.SuspendLayout();
            this.aboutRibbonGroup.SuspendLayout();
            // 
            // tab1
            // 
            this.tab1.ControlId.ControlIdType = Microsoft.Office.Tools.Ribbon.RibbonControlIdType.Office;
            this.tab1.Label = "TabAddIns";
            this.tab1.Name = "tab1";
            // 
            // Word2010DepositMORibbonTab
            // 
            this.Word2010DepositMORibbonTab.Groups.Add(this.Word2010DepositMOMainGroup);
            this.Word2010DepositMORibbonTab.Groups.Add(this.quickSubmissionRibbonGroup);
            this.Word2010DepositMORibbonTab.Groups.Add(this.aboutRibbonGroup);
            this.Word2010DepositMORibbonTab.KeyTip = "DEP";
            this.Word2010DepositMORibbonTab.Label = "DepositMO 2010";
            this.Word2010DepositMORibbonTab.Name = "Word2010DepositMORibbonTab";
            // 
            // Word2010DepositMOMainGroup
            // 
            this.Word2010DepositMOMainGroup.DialogLauncher = ribbonDialogLauncherImpl1;
            this.Word2010DepositMOMainGroup.Items.Add(this.Word2010DepositMORepositoryButton);
            this.Word2010DepositMOMainGroup.Items.Add(this.Word2010DepositMORepositoryHideButton);
            this.Word2010DepositMOMainGroup.Label = "Repository control";
            this.Word2010DepositMOMainGroup.Name = "Word2010DepositMOMainGroup";
            // 
            // Word2010DepositMORepositoryButton
            // 
            this.Word2010DepositMORepositoryButton.ControlSize = Microsoft.Office.Core.RibbonControlSize.RibbonControlSizeLarge;
            this.Word2010DepositMORepositoryButton.Image = global::uk.ac.soton.ses.Word2010DepositMOAddIn.Properties.Resources.DocumentImage;
            this.Word2010DepositMORepositoryButton.Label = "Show";
            this.Word2010DepositMORepositoryButton.Name = "Word2010DepositMORepositoryButton";
            this.Word2010DepositMORepositoryButton.ScreenTip = "Displays the repository control panels if they aren\'t already shown";
            this.Word2010DepositMORepositoryButton.ShowImage = true;
            this.Word2010DepositMORepositoryButton.Click += new Microsoft.Office.Tools.Ribbon.RibbonControlEventHandler(this.Word2010DepositMORepositoryButton_Click);
            // 
            // Word2010DepositMORepositoryHideButton
            // 
            this.Word2010DepositMORepositoryHideButton.ControlSize = Microsoft.Office.Core.RibbonControlSize.RibbonControlSizeLarge;
            this.Word2010DepositMORepositoryHideButton.Image = global::uk.ac.soton.ses.Word2010DepositMOAddIn.Properties.Resources.DocumentImage;
            this.Word2010DepositMORepositoryHideButton.Label = "Hide";
            this.Word2010DepositMORepositoryHideButton.Name = "Word2010DepositMORepositoryHideButton";
            this.Word2010DepositMORepositoryHideButton.ScreenTip = "Hides the repository controls if they\'re visible";
            this.Word2010DepositMORepositoryHideButton.ShowImage = true;
            this.Word2010DepositMORepositoryHideButton.Click += new Microsoft.Office.Tools.Ribbon.RibbonControlEventHandler(this.Word2010DepositMORepositoryHideButton_Click);
            // 
            // quickSubmissionRibbonGroup
            // 
            this.quickSubmissionRibbonGroup.DialogLauncher = ribbonDialogLauncherImpl2;
            this.quickSubmissionRibbonGroup.Items.Add(this.endpointEditBox);
            this.quickSubmissionRibbonGroup.Items.Add(this.quickSubmitButton);
            this.quickSubmissionRibbonGroup.Label = "Quick submission";
            this.quickSubmissionRibbonGroup.Name = "quickSubmissionRibbonGroup";
            // 
            // endpointEditBox
            // 
            this.endpointEditBox.Label = "Endpoint";
            this.endpointEditBox.Name = "endpointEditBox";
            this.endpointEditBox.SizeString = "http://depositmo.eprints.org/sword-app/deposit/inbox";
            this.endpointEditBox.SuperTip = "The endpoint against which submission will occur";
            this.endpointEditBox.Text = null;
            // 
            // quickSubmitButton
            // 
            this.quickSubmitButton.Image = global::uk.ac.soton.ses.Word2010DepositMOAddIn.Properties.Resources.DocumentImage;
            this.quickSubmitButton.Label = "Submit";
            this.quickSubmitButton.Name = "quickSubmitButton";
            this.quickSubmitButton.ShowImage = true;
            this.quickSubmitButton.SuperTip = resources.GetString("quickSubmitButton.SuperTip");
            this.quickSubmitButton.Click += new Microsoft.Office.Tools.Ribbon.RibbonControlEventHandler(this.quickSubmitButton_Click);
            // 
            // aboutRibbonGroup
            // 
            this.aboutRibbonGroup.Items.Add(this.aboutRibbonButton);
            this.aboutRibbonGroup.Label = "About";
            this.aboutRibbonGroup.Name = "aboutRibbonGroup";
            // 
            // aboutRibbonButton
            // 
            this.aboutRibbonButton.ControlSize = Microsoft.Office.Core.RibbonControlSize.RibbonControlSizeLarge;
            this.aboutRibbonButton.Image = global::uk.ac.soton.ses.Word2010DepositMOAddIn.Properties.Resources.DocumentImage;
            this.aboutRibbonButton.Label = "About DepositMO 2010";
            this.aboutRibbonButton.Name = "aboutRibbonButton";
            this.aboutRibbonButton.ShowImage = true;
            this.aboutRibbonButton.SuperTip = "Displays some information about the DepositMO Word author add-in";
            this.aboutRibbonButton.Click += new Microsoft.Office.Tools.Ribbon.RibbonControlEventHandler(this.aboutRibbonButton_Click);
            // 
            // Word2010DepositMORibbon
            // 
            this.Name = "Word2010DepositMORibbon";
            this.RibbonType = "Microsoft.Word.Document";
            this.Tabs.Add(this.tab1);
            this.Tabs.Add(this.Word2010DepositMORibbonTab);
            this.Load += new Microsoft.Office.Tools.Ribbon.RibbonUIEventHandler(this.Word2010DepositMORibbon_Load);
            this.tab1.ResumeLayout(false);
            this.tab1.PerformLayout();
            this.Word2010DepositMORibbonTab.ResumeLayout(false);
            this.Word2010DepositMORibbonTab.PerformLayout();
            this.Word2010DepositMOMainGroup.ResumeLayout(false);
            this.Word2010DepositMOMainGroup.PerformLayout();
            this.quickSubmissionRibbonGroup.ResumeLayout(false);
            this.quickSubmissionRibbonGroup.PerformLayout();
            this.aboutRibbonGroup.ResumeLayout(false);
            this.aboutRibbonGroup.PerformLayout();

        }

        #endregion

        internal Microsoft.Office.Tools.Ribbon.RibbonTab tab1;
        private Microsoft.Office.Tools.Ribbon.RibbonTab Word2010DepositMORibbonTab;
        internal Microsoft.Office.Tools.Ribbon.RibbonGroup Word2010DepositMOMainGroup;
        internal Microsoft.Office.Tools.Ribbon.RibbonButton Word2010DepositMORepositoryButton;
        internal Microsoft.Office.Tools.Ribbon.RibbonButton Word2010DepositMORepositoryHideButton;
        internal Microsoft.Office.Tools.Ribbon.RibbonGroup quickSubmissionRibbonGroup;
        internal Microsoft.Office.Tools.Ribbon.RibbonEditBox endpointEditBox;
        internal Microsoft.Office.Tools.Ribbon.RibbonButton quickSubmitButton;
        internal Microsoft.Office.Tools.Ribbon.RibbonGroup aboutRibbonGroup;
        internal Microsoft.Office.Tools.Ribbon.RibbonButton aboutRibbonButton;
    }

    partial class ThisRibbonCollection
    {
        internal Word2010DepositMORibbon Word2010DepositMORibbon
        {
            get { return this.GetRibbon<Word2010DepositMORibbon>(); }
        }
    }
}
