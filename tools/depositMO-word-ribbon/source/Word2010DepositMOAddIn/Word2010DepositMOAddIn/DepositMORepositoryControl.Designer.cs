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
    partial class DepositMORepositoryControl
    {
        /// <summary> 
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

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
            this.repositoryControlGroupBox = new System.Windows.Forms.GroupBox();
            this.documentLocationTextBox = new System.Windows.Forms.TextBox();
            this.documentLocationLabel = new System.Windows.Forms.Label();
            this.addToGroupButton = new System.Windows.Forms.Button();
            this.updateEprintButton = new System.Windows.Forms.Button();
            this.passwordTextBox = new System.Windows.Forms.TextBox();
            this.passwordLabel = new System.Windows.Forms.Label();
            this.usernameTextBox = new System.Windows.Forms.TextBox();
            this.usernameLabel = new System.Windows.Forms.Label();
            this.repositoryLocationTextBox = new System.Windows.Forms.TextBox();
            this.repositoryLocationLabel = new System.Windows.Forms.Label();
            this.submitToThisRepositoryButton = new System.Windows.Forms.Button();
            this.groupRepositoryGroupBox = new System.Windows.Forms.GroupBox();
            this.submitToAllButton = new System.Windows.Forms.Button();
            this.removeFromGroupButton = new System.Windows.Forms.Button();
            this.repositoryCollectionTabControl = new System.Windows.Forms.TabControl();
            this.submissionLogTextBox = new System.Windows.Forms.TextBox();
            this.messagesGroupBox = new System.Windows.Forms.GroupBox();
            this.repositoryControlGroupBox.SuspendLayout();
            this.groupRepositoryGroupBox.SuspendLayout();
            this.messagesGroupBox.SuspendLayout();
            this.SuspendLayout();
            // 
            // repositoryControlGroupBox
            // 
            this.repositoryControlGroupBox.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left)
                        | System.Windows.Forms.AnchorStyles.Right)));
            this.repositoryControlGroupBox.Controls.Add(this.documentLocationTextBox);
            this.repositoryControlGroupBox.Controls.Add(this.documentLocationLabel);
            this.repositoryControlGroupBox.Controls.Add(this.addToGroupButton);
            this.repositoryControlGroupBox.Controls.Add(this.updateEprintButton);
            this.repositoryControlGroupBox.Controls.Add(this.passwordTextBox);
            this.repositoryControlGroupBox.Controls.Add(this.passwordLabel);
            this.repositoryControlGroupBox.Controls.Add(this.usernameTextBox);
            this.repositoryControlGroupBox.Controls.Add(this.usernameLabel);
            this.repositoryControlGroupBox.Controls.Add(this.repositoryLocationTextBox);
            this.repositoryControlGroupBox.Controls.Add(this.repositoryLocationLabel);
            this.repositoryControlGroupBox.Controls.Add(this.submitToThisRepositoryButton);
            this.repositoryControlGroupBox.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.repositoryControlGroupBox.Location = new System.Drawing.Point(4, 4);
            this.repositoryControlGroupBox.Name = "repositoryControlGroupBox";
            this.repositoryControlGroupBox.Size = new System.Drawing.Size(200, 223);
            this.repositoryControlGroupBox.TabIndex = 0;
            this.repositoryControlGroupBox.TabStop = false;
            this.repositoryControlGroupBox.Text = "Repository Control";
            // 
            // documentLocationTextBox
            // 
            this.documentLocationTextBox.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left)
                        | System.Windows.Forms.AnchorStyles.Right)));
            this.documentLocationTextBox.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.documentLocationTextBox.Location = new System.Drawing.Point(7, 133);
            this.documentLocationTextBox.Name = "documentLocationTextBox";
            this.documentLocationTextBox.Size = new System.Drawing.Size(187, 21);
            this.documentLocationTextBox.TabIndex = 10;
            // 
            // documentLocationLabel
            // 
            this.documentLocationLabel.AutoSize = true;
            this.documentLocationLabel.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.documentLocationLabel.Location = new System.Drawing.Point(7, 117);
            this.documentLocationLabel.Name = "documentLocationLabel";
            this.documentLocationLabel.Size = new System.Drawing.Size(95, 13);
            this.documentLocationLabel.TabIndex = 9;
            this.documentLocationLabel.Text = "Document location";
            // 
            // addToGroupButton
            // 
            this.addToGroupButton.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.addToGroupButton.Location = new System.Drawing.Point(94, 159);
            this.addToGroupButton.Name = "addToGroupButton";
            this.addToGroupButton.Size = new System.Drawing.Size(82, 52);
            this.addToGroupButton.TabIndex = 8;
            this.addToGroupButton.Text = "Add to repository collection";
            this.addToGroupButton.UseVisualStyleBackColor = true;
            this.addToGroupButton.Click += new System.EventHandler(this.addToGroupButton_Click);
            // 
            // updateEprintButton
            // 
            this.updateEprintButton.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.updateEprintButton.Location = new System.Drawing.Point(7, 188);
            this.updateEprintButton.Name = "updateEprintButton";
            this.updateEprintButton.Size = new System.Drawing.Size(76, 23);
            this.updateEprintButton.TabIndex = 7;
            this.updateEprintButton.Text = "Update";
            this.updateEprintButton.UseVisualStyleBackColor = true;
            this.updateEprintButton.Click += new System.EventHandler(this.updateEprintButton_Click);
            // 
            // passwordTextBox
            // 
            this.passwordTextBox.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left)
                        | System.Windows.Forms.AnchorStyles.Right)));
            this.passwordTextBox.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.passwordTextBox.Location = new System.Drawing.Point(69, 89);
            this.passwordTextBox.Name = "passwordTextBox";
            this.passwordTextBox.PasswordChar = '*';
            this.passwordTextBox.Size = new System.Drawing.Size(125, 21);
            this.passwordTextBox.TabIndex = 6;
            // 
            // passwordLabel
            // 
            this.passwordLabel.AutoSize = true;
            this.passwordLabel.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.passwordLabel.Location = new System.Drawing.Point(9, 92);
            this.passwordLabel.Name = "passwordLabel";
            this.passwordLabel.Size = new System.Drawing.Size(53, 13);
            this.passwordLabel.TabIndex = 5;
            this.passwordLabel.Text = "Password";
            // 
            // usernameTextBox
            // 
            this.usernameTextBox.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left)
                        | System.Windows.Forms.AnchorStyles.Right)));
            this.usernameTextBox.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.usernameTextBox.Location = new System.Drawing.Point(69, 63);
            this.usernameTextBox.Name = "usernameTextBox";
            this.usernameTextBox.Size = new System.Drawing.Size(125, 21);
            this.usernameTextBox.TabIndex = 4;
            // 
            // usernameLabel
            // 
            this.usernameLabel.AutoSize = true;
            this.usernameLabel.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.usernameLabel.Location = new System.Drawing.Point(8, 66);
            this.usernameLabel.Name = "usernameLabel";
            this.usernameLabel.Size = new System.Drawing.Size(55, 13);
            this.usernameLabel.TabIndex = 3;
            this.usernameLabel.Text = "Username";
            // 
            // repositoryLocationTextBox
            // 
            this.repositoryLocationTextBox.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left)
                        | System.Windows.Forms.AnchorStyles.Right)));
            this.repositoryLocationTextBox.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.repositoryLocationTextBox.Location = new System.Drawing.Point(7, 37);
            this.repositoryLocationTextBox.Name = "repositoryLocationTextBox";
            this.repositoryLocationTextBox.Size = new System.Drawing.Size(187, 21);
            this.repositoryLocationTextBox.TabIndex = 2;
            // 
            // repositoryLocationLabel
            // 
            this.repositoryLocationLabel.AutoSize = true;
            this.repositoryLocationLabel.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.repositoryLocationLabel.Location = new System.Drawing.Point(7, 20);
            this.repositoryLocationLabel.Name = "repositoryLocationLabel";
            this.repositoryLocationLabel.Size = new System.Drawing.Size(99, 13);
            this.repositoryLocationLabel.TabIndex = 1;
            this.repositoryLocationLabel.Text = "Repository location";
            // 
            // submitToThisRepositoryButton
            // 
            this.submitToThisRepositoryButton.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.submitToThisRepositoryButton.Location = new System.Drawing.Point(7, 159);
            this.submitToThisRepositoryButton.Name = "submitToThisRepositoryButton";
            this.submitToThisRepositoryButton.Size = new System.Drawing.Size(76, 23);
            this.submitToThisRepositoryButton.TabIndex = 0;
            this.submitToThisRepositoryButton.Tag = "";
            this.submitToThisRepositoryButton.Text = "Submit";
            this.submitToThisRepositoryButton.UseVisualStyleBackColor = true;
            this.submitToThisRepositoryButton.Click += new System.EventHandler(this.submitToThisRepositoryButton_Click);
            // 
            // groupRepositoryGroupBox
            // 
            this.groupRepositoryGroupBox.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left)
                        | System.Windows.Forms.AnchorStyles.Right)));
            this.groupRepositoryGroupBox.Controls.Add(this.submitToAllButton);
            this.groupRepositoryGroupBox.Controls.Add(this.removeFromGroupButton);
            this.groupRepositoryGroupBox.Controls.Add(this.repositoryCollectionTabControl);
            this.groupRepositoryGroupBox.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.groupRepositoryGroupBox.Location = new System.Drawing.Point(4, 234);
            this.groupRepositoryGroupBox.Name = "groupRepositoryGroupBox";
            this.groupRepositoryGroupBox.Size = new System.Drawing.Size(200, 206);
            this.groupRepositoryGroupBox.TabIndex = 1;
            this.groupRepositoryGroupBox.TabStop = false;
            this.groupRepositoryGroupBox.Text = "Repository Collection";
            // 
            // submitToAllButton
            // 
            this.submitToAllButton.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.submitToAllButton.Location = new System.Drawing.Point(7, 177);
            this.submitToAllButton.Name = "submitToAllButton";
            this.submitToAllButton.Size = new System.Drawing.Size(89, 23);
            this.submitToAllButton.TabIndex = 10;
            this.submitToAllButton.Text = "Submit to all";
            this.submitToAllButton.UseVisualStyleBackColor = true;
            this.submitToAllButton.Click += new System.EventHandler(this.submitToAllButton_Click);
            // 
            // removeFromGroupButton
            // 
            this.removeFromGroupButton.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.removeFromGroupButton.Location = new System.Drawing.Point(102, 177);
            this.removeFromGroupButton.Name = "removeFromGroupButton";
            this.removeFromGroupButton.Size = new System.Drawing.Size(91, 23);
            this.removeFromGroupButton.TabIndex = 9;
            this.removeFromGroupButton.Text = "Remove";
            this.removeFromGroupButton.UseVisualStyleBackColor = true;
            this.removeFromGroupButton.Click += new System.EventHandler(this.removeFromGroupButton_Click);
            // 
            // repositoryCollectionTabControl
            // 
            this.repositoryCollectionTabControl.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left)
                        | System.Windows.Forms.AnchorStyles.Right)));
            this.repositoryCollectionTabControl.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.repositoryCollectionTabControl.Location = new System.Drawing.Point(7, 20);
            this.repositoryCollectionTabControl.Name = "repositoryCollectionTabControl";
            this.repositoryCollectionTabControl.SelectedIndex = 0;
            this.repositoryCollectionTabControl.Size = new System.Drawing.Size(187, 151);
            this.repositoryCollectionTabControl.TabIndex = 0;
            // 
            // submissionLogTextBox
            // 
            this.submissionLogTextBox.BorderStyle = System.Windows.Forms.BorderStyle.None;
            this.submissionLogTextBox.Dock = System.Windows.Forms.DockStyle.Fill;
            this.submissionLogTextBox.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.submissionLogTextBox.Location = new System.Drawing.Point(3, 17);
            this.submissionLogTextBox.Multiline = true;
            this.submissionLogTextBox.Name = "submissionLogTextBox";
            this.submissionLogTextBox.ReadOnly = true;
            this.submissionLogTextBox.ScrollBars = System.Windows.Forms.ScrollBars.Vertical;
            this.submissionLogTextBox.Size = new System.Drawing.Size(194, 80);
            this.submissionLogTextBox.TabIndex = 2;
            // 
            // messagesGroupBox
            // 
            this.messagesGroupBox.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left)
                        | System.Windows.Forms.AnchorStyles.Right)));
            this.messagesGroupBox.Controls.Add(this.submissionLogTextBox);
            this.messagesGroupBox.Font = new System.Drawing.Font("Tahoma", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(0)));
            this.messagesGroupBox.Location = new System.Drawing.Point(4, 446);
            this.messagesGroupBox.Name = "messagesGroupBox";
            this.messagesGroupBox.Size = new System.Drawing.Size(200, 100);
            this.messagesGroupBox.TabIndex = 3;
            this.messagesGroupBox.TabStop = false;
            this.messagesGroupBox.Text = "Messages";
            // 
            // DepositMORepositoryControl
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.Controls.Add(this.messagesGroupBox);
            this.Controls.Add(this.groupRepositoryGroupBox);
            this.Controls.Add(this.repositoryControlGroupBox);
            this.Name = "DepositMORepositoryControl";
            this.Size = new System.Drawing.Size(207, 559);
            this.Load += new System.EventHandler(this.DepositMORepositoryControl_Load);
            this.repositoryControlGroupBox.ResumeLayout(false);
            this.repositoryControlGroupBox.PerformLayout();
            this.groupRepositoryGroupBox.ResumeLayout(false);
            this.messagesGroupBox.ResumeLayout(false);
            this.messagesGroupBox.PerformLayout();
            this.ResumeLayout(false);

        }

        #endregion

        private System.Windows.Forms.GroupBox repositoryControlGroupBox;
        private System.Windows.Forms.TextBox repositoryLocationTextBox;
        private System.Windows.Forms.Label repositoryLocationLabel;
        private System.Windows.Forms.Button submitToThisRepositoryButton;
        private System.Windows.Forms.TextBox passwordTextBox;
        private System.Windows.Forms.Label passwordLabel;
        private System.Windows.Forms.TextBox usernameTextBox;
        private System.Windows.Forms.Label usernameLabel;
        private System.Windows.Forms.Button updateEprintButton;
        private System.Windows.Forms.Button addToGroupButton;
        private System.Windows.Forms.GroupBox groupRepositoryGroupBox;
        private System.Windows.Forms.Button removeFromGroupButton;
        private System.Windows.Forms.TabControl repositoryCollectionTabControl;
        private System.Windows.Forms.Button submitToAllButton;
        private System.Windows.Forms.TextBox submissionLogTextBox;
        private System.Windows.Forms.TextBox documentLocationTextBox;
        private System.Windows.Forms.Label documentLocationLabel;
        private System.Windows.Forms.GroupBox messagesGroupBox;
    }
}
