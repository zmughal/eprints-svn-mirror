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
using System.Xml;

namespace uk.ac.soton.ses
{
    /// <summary>
    /// SWORD author
    /// </summary>
    public class SwordListAuthor
    {
        private string name;

        /// <summary>
        /// Gets or sets the author's name
        /// </summary>
        public string Name { get { return this.name; } set { this.name = value; }  }

        /// <summary>
        /// Author
        /// </summary>
        /// <param name="name">Author's name</param>
        public SwordListAuthor(string name)
        {
            this.Name = name;
        }
    }

    /// <summary>
    /// SWORD entry for the collection list
    /// </summary>
    public class SwordListEntry
    {
        private string title;
        private string href;
        private string summary;
        private DateTime updated;
        private string id;
        private List<SwordListAuthor> authors;

        /// <summary>
        /// Title of the entry
        /// </summary>
        public string Title { get { return this.title; } set { this.title = value; } }

        /// <summary>
        /// Href to the entry
        /// </summary>
        public string Href { get { return this.href; } set { this.href = value; } }

        /// <summary>
        /// Summary of the entry
        /// </summary>
        public string Summary { get { return this.summary; } set { this.summary = value; } }

        /// <summary>
        /// Update time of the entry
        /// </summary>
        public DateTime Updated { get { return this.updated; } set { this.updated = value; } }

        /// <summary>
        /// ID of the entry
        /// </summary>
        public string Id { get { return this.id; } set { this.id = value; } }

        /// <summary>
        /// List of authors for the entry
        /// </summary>
        public List<SwordListAuthor> Authors { get { return this.authors; } }

        /// <summary>
        /// Adds the author <code>name</code> to the entry
        /// </summary>
        /// <param name="name">Author name</param>
        public void AddAuthor(string name)
        {
            SwordListAuthor author = new SwordListAuthor(name);
            this.authors.Add(author);
        }

        /// <summary>
        /// Creates a new entry for the collection with the supplied title
        /// </summary>
        /// <param name="title">Entry title</param>
        public SwordListEntry(string title)
        {
            this.authors = new List<SwordListAuthor>();
            this.Title = title;
        }
    }

    /// <summary>
    /// SWORD list reader
    /// </summary>
    public class SwordListReader
    {
        private XmlDocument swordListXml = null;
        private XmlNamespaceManager xnm = null;

        private string title;
        private DateTime updated;

        private List<SwordListEntry> entries = new List<SwordListEntry>();

        /// <summary>
        /// List of entries in the collection
        /// </summary>
        public List<SwordListEntry> Entries { get { return this.entries; } }

        /// <summary>
        /// Creates a new SwordListReader from the supplied listing document
        /// </summary>
        /// <param name="swordListXml">XML document containing list of entries</param>
        public SwordListReader(XmlDocument swordListXml)
        {
            this.swordListXml = swordListXml;
            if (this.swordListXml != null)
            {
                this.xnm = new XmlNamespaceManager(this.swordListXml.NameTable);                
                this.xnm.AddNamespace("atom", "http://www.w3.org/2005/Atom");
                
            }
            this.ParseEntries();
        }

        /// <summary>
        /// Returns the entry that matches the supplied ID
        /// </summary>
        /// <param name="id">ID to match</param>
        /// <returns>Matching entry, else null</returns>
        public SwordListEntry GetEntryById(string id)
        {
            foreach (SwordListEntry sle in this.Entries)
            {
                if (sle.Id.Equals(id))
                {
                    return sle;
                }
            }
            return null;
        }

        /// <summary>
        /// Parses the entries in the supplied document and populates the list
        /// </summary>
        internal void ParseEntries()
        {
            if (this.swordListXml == null)
            {
                // don't parse a null document
                return;
            }

            this.title = this.swordListXml.SelectSingleNode("/atom:feed/atom:title", this.xnm).InnerText;
            this.updated = DateTime.Parse(this.swordListXml.SelectSingleNode("/atom:feed/atom:updated", this.xnm).InnerText);

            // get entries
            XmlNodeList nodeList = this.swordListXml.SelectNodes("/atom:feed/atom:entry", this.xnm);
            foreach (XmlNode node in nodeList)
            {
                SwordListEntry sle = new SwordListEntry(node.SelectSingleNode("atom:title", this.xnm).InnerText);
                sle.Updated = DateTime.Parse(node.SelectSingleNode("atom:updated", this.xnm).InnerText);                
                sle.Id = node.SelectSingleNode("atom:id", this.xnm).InnerText;
                sle.Summary = node.SelectSingleNode("atom:summary", this.xnm).InnerText;
                XmlNodeList authorList = node.SelectNodes("atom:author", this.xnm);
                foreach (XmlNode author in authorList)
                {
                    sle.AddAuthor(author.SelectSingleNode("atom:name", this.xnm).InnerText);
                }                                
                this.Entries.Add(sle);
            }
            return;
        }
    }
}
