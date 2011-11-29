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
using System.Drawing;
using System.Data;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace uk.ac.soton.ses.Word2010DepositMOAddIn
{
    /// <summary>
    /// Custom Windows Forms user control for repository groups in Microsoft Word 2010 DepositMO add-in
    /// </summary>
    public partial class RepositoryGroupUserControl : UserControl
    {
        /// <summary>
        /// Endpoint
        /// </summary>
        public string endpoint { get { return this.repositoryLocationTextBox.Text; } set { this.repositoryLocationTextBox.Text = value; } }

        /// <summary>
        /// Username
        /// </summary>
        public string username { get { return this.usernameTextBox.Text; } set { this.usernameTextBox.Text = value; } }

        /// <summary>
        /// Password
        /// </summary>
        public string password { get { return this.passwordTextBox.Text; } set { this.passwordTextBox.Text = value; } }

        /// <summary>
        /// Control ID
        /// </summary>
        public int id { get { return int.Parse(this.identLabel.Text); } set { this.identLabel.Text = value.ToString(); } }

        /// <summary>
        /// Default constructor. Sets endpoint, username and password
        /// </summary>
        public RepositoryGroupUserControl()
        {
            InitializeComponent();
            this.endpoint = Globals.Word2010DepositMOAddIn.DefaultEndpoint;
            this.username = Globals.Word2010DepositMOAddIn.DefaultUsername;
            this.password = Globals.Word2010DepositMOAddIn.DefaultPassword;
        }
    }
}
