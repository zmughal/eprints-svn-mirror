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
    /// SWORD 2 Atom XML reader
    /// </summary>
    public class SwordAtomReader
    {
        /// <summary>
        /// The Atom XML document
        /// </summary>
        private XmlDocument atomXml = null;
        
        /// <summary>
        /// XML namespace manager for Atom XML document
        /// </summary>
        private XmlNamespaceManager xnm = null;

        /// <summary>
        /// Creates a new SWORD Atom reader from the supplied XML document
        /// </summary>
        /// <param name="atomXml">Atom XML</param>
        public SwordAtomReader(XmlDocument atomXml)        
        {
            this.atomXml = atomXml;
            if (this.atomXml != null)
            {
                this.xnm = new XmlNamespaceManager(this.atomXml.NameTable);
                this.xnm.AddNamespace("atom", "http://www.w3.org/2005/Atom");
                this.xnm.AddNamespace("sword", "http://purl.org/net/sword/");
            }
        }

        private string GetXPathValue(string xPathQuery)
        {
            XmlNode singleNode = this.GetSingleNode(xPathQuery);
            if (singleNode == null)
            {
                return null;
            }
            return singleNode.Value;
        }

        private string GetXPathText(string xPathQuery)
        {
            XmlNode singleNode = this.GetSingleNode(xPathQuery);
            if (singleNode == null)
            {
                return null;
            }
            return singleNode.InnerText;
        }

        private string[] GetXPathTextArray(string xPathQuery)
        {
            XmlNodeList multipleNodes = this.GetMultipleNodes(xPathQuery);
            if (multipleNodes == null)
            {
                return null;
            }
            string[] nodetexts = new string[multipleNodes.Count];
            for (int i = 0; i < multipleNodes.Count; i++)
            {
                nodetexts[i] = multipleNodes[i].InnerText;
            }
            return nodetexts;
        }

        private XmlNode GetSingleNode(string xPathQuery)
        {
            if (this.atomXml == null)
            {
                return null;
            }
            return this.atomXml.SelectSingleNode(xPathQuery, this.xnm);            
        }

        private XmlNodeList GetMultipleNodes(string xPathQuery)
        {
            if (this.atomXml == null)
            {
                return null;
            }
            return this.atomXml.SelectNodes(xPathQuery, this.xnm);
        }

        /// <summary>
        /// Gets or sets the Atom response on this instance
        /// </summary>
        public XmlDocument AtomXml
        {
            get { return this.atomXml; }
            set { this.atomXml = value; }
        }

        /*
         * Note that these are not exhaustive and subject to change until the spec is finalised
         */

        /// <summary>
        /// Edit media href
        /// </summary>
        public string EditMediaHref { 
            get 
            {
                // DSpace will have the type set here
                string returnValue = this.GetXPathValue(@"/atom:entry/atom:link[@rel=""edit-media"" and @type=""application/atom+xml; type=feed""]/@href");

                if (returnValue == null)
                {
                    // EPrints won't care
                    returnValue = this.GetXPathValue(@"/atom:entry/atom:link[@rel=""edit-media""]/@href");
                }
                return returnValue;
            } 
        }

        /// <summary>
        /// Edit href
        /// </summary>
        public string EditHref { get { return this.GetXPathValue(@"/atom:entry/atom:link[@rel=""edit""]/@href"); } }

        /// <summary>
        /// Contents href
        /// </summary>
        public string ContentsHref { get { return this.GetXPathValue(@"/atom:entry/atom:link[@rel=""contents""]/@href"); } }

        /// <summary>
        /// Atom ID
        /// </summary>
        public string AtomId { get { return this.GetXPathText(@"/atom:entry/id"); } }            

        /// <summary>
        /// Atom title
        /// </summary>
        public string AtomTitle { get { return this.GetXPathText("/atom:entry/atom:title"); } }

        /// <summary>
        /// Atom generator
        /// </summary>
        public string AtomGenerator { get { return this.GetXPathText("/atom:entry/atom:generator"); } }

        /// <summary>
        /// Atom generator URI
        /// </summary>
        public string AtomGeneratorUri { get { return this.GetXPathText("/atom:entry/atom:generator/@uri"); } }

        /// <summary>
        /// Atom generator version
        /// </summary>
        public string AtomGeneratorVersion { get { return this.GetXPathText("/atom:entry/atom:generator/@version"); } }

        /// <summary>
        /// Atom summary
        /// </summary>
        public string AtomSummary { get { return this.GetXPathText("/atom:entry/atom:summary/@type"); } }

        /// <summary>
        /// Atom content type
        /// </summary>
        public string AtomContentType { get { return this.GetXPathText("/atom:entry/atom:content/@type"); } }

        /// <summary>
        /// Atom content source
        /// </summary>
        public string AtomContentSrc { get { return this.GetXPathText("/atom:entry/atom:content/@src"); } }

        /// <summary>
        /// SWORD treatment
        /// </summary>
        public string SwordTreatment { get { return this.GetXPathText("/atom:entry/sword:treatment"); } }

        /// <summary>
        /// SWORD packaging
        /// </summary>
        public string SwordPackaging { get { return this.GetXPathText("/atom:entry/sword:packaging"); } }

        /// <summary>
        /// SWORD noop
        /// </summary>
        public string SwordNoop { get { return this.GetXPathText("/atom:entry/sword:noOp"); } }

        /// <summary>
        /// Atom updated
        /// </summary>
        public DateTime AtomUpdated { get { return DateTime.Parse(this.GetXPathText("/atom:entry/atom:updated")); } }

        /// <summary>
        /// Atom published
        /// </summary>
        public DateTime AtomPublished { get { return DateTime.Parse(this.GetXPathText("/atom:entry/atom:published")); } }
    }
}
