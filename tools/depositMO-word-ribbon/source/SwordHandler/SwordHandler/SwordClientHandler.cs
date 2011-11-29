/*
   SwordClientHandler.cs
  
   SWORD 2.0 API for Microsoft .NET 4.0
  
   Copyright 2010-2011 University of Southampton

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
using System.Text;
using System.Net;
using System.Xml;
using System.Diagnostics;
using System.IO;

namespace uk.ac.soton.ses
{
    /// <summary>
    /// SWORD 2 client implementation for .NET
    /// 
    /// Library functions for communicating with a SWORD 2 compliant server    
    /// </summary>
    public class SwordClientHandler
    {
            /// <summary>
        /// Buffer size for uploads in bytes
        /// </summary>
        private static int BUFFER_SIZE = 16 * 1024;

        /// <summary>
        /// EP2 packaging header value
        /// </summary>
        private static string EP2_PACKAGING = "http://eprints.org/ep2/data/2.0";

        /// <summary>
        /// .docx content type
        /// </summary>
        private static string DOCX_CONTENTTYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";

        /// <summary>
        /// The path for listing records
        /// </summary>
        private static string LIST_RECORD_PATH = "/id/records";

        /// <summary>
        /// Should media be extracted by default, or ignored?
        /// Note that this is going into a header so it should be a string rather
        /// than a Boolean
        /// </summary>
        private static string EXTRACT_MEDIA = "true";

        /// <summary>
        /// TODO: Whether the inbox URL should be resolved from the HTML of the supplied endpoint
        /// </summary>
        /// TODO
        internal bool _resolveInbox = false;

        /// <summary>
        /// The repository username
        /// </summary>
        private string _username;
        
        /// <summary>
        /// The repository password
        /// </summary>
        private string _password;

        /// <summary>
        /// The main repository endpoint
        /// </summary>
        private string _endpoint;

        /// <summary>
        /// Sets the username associated with the repository
        /// </summary>
        public string Username
        {
            set
            {
                this._username = value;
            }
        }

        /// <summary>
        /// Sets the password associated with the repository
        /// </summary>
        public string Password
        {
            set
            {
                this._password = value;
            }
        }

        /// <summary>
        /// Sets the endpoint associated with the repository
        /// </summary>
        public string Endpoint
        {
            set
            {
                this._endpoint = value;
            }
        }

        /// <summary>
        /// Creates a new SWORD 2 handler instance
        /// </summary>
        /// <param name="username">The repository username</param>
        /// <param name="password">The repository password</param>
        /// <param name="endpoint">The main repository endpoint</param>
        public SwordClientHandler(string username, string password, string endpoint)
        {
            this._username = username;
            this._password = password;
            this._endpoint = endpoint;
        }

        /// <summary>
        /// Creates a new SWORD 2 handler instance
        /// </summary>
        /// <param name="username">The repository username</param>
        /// <param name="password">The repository password</param>
        /// <param name="endpoint">The main repository endpoint</param>
        /// <param name="resolveInbox">Whether to attempt to resolve the 'inbox' from the supplied endpoint</param>
        public SwordClientHandler(string username, string password, string endpoint, bool resolveInbox)
        {
            this._username = username;
            this._password = password;
            this._endpoint = endpoint;
            this._resolveInbox = resolveInbox;
            this.ResolveInbox();
        }

        /// <summary>
        /// Resolves the inbox based on the currently-supplied endpoint
        /// </summary>
        internal void ResolveInbox()
        {
            // if we're not supposed to resolve the inbox, skip this step
            if (!this._resolveInbox)
            {
                return;
            }

            string inbox = HtmlScraper.GetAttributeContent(this._endpoint, "link", "rel", "SwordDeposit", "href");

            if (!String.IsNullOrEmpty(inbox))
            {
                this._endpoint = inbox;
            }
        }        

        /// <summary>
        /// Creates a web request instance to the target URI, adding in basic authorisation from the
        /// username and password on the instance, and setting the <code>accept</code> header of the request
        /// to be <code>application/atom+xml</code>
        /// </summary>
        /// <param name="targetUri">The URI to which the request should be made</param>
        /// <returns>Web request</returns>
        private HttpWebRequest GetBasicAuthAtomWebRequest(string targetUri)
        {
            return this.GetBasicAuthAtomWebRequest(new Uri(targetUri));
        }

        /// <summary>
        /// Creates a web request instance to the target URI, adding in basic authorisation from the
        /// username and password on the instance, and setting the <code>accept</code> header of the request
        /// to be <code>application/atom+xml</code>
        /// </summary>
        /// <param name="targetUri">The URI to which the request should be made</param>
        /// <returns>Web request</returns>
        private HttpWebRequest GetBasicAuthAtomWebRequest(Uri targetUri)
        {
            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(targetUri);
            CredentialCache cc = new CredentialCache();
            cc.Add(targetUri, "Basic", new NetworkCredential(this._username, this._password, "Authenticate"));                 
            //cc.Add(new Uri(targetUri), "Basic", new NetworkCredential(this._username, this._password));                 
            request.Credentials = cc;            
            request.Headers.Add(HttpRequestHeader.Authorization, "Basic " + Convert.ToBase64String(new ASCIIEncoding().GetBytes(this._username + ':' + this._password)));
            request.Accept = "application/atom+xml";
            return request;
        }

        /// <summary>
        /// Writes the file in <code>filename</code> to the web request <code>wr</code>.
        /// This uses a buffer whose size is stored statically in <code>BUFFER_SIZE</code>
        /// to speed up the transfer
        /// </summary>
        /// <param name="filename">The absolute filename to send</param>
        /// <param name="wr">The web request on which to send the file</param>
        private void WriteFileToRequest(string filename, HttpWebRequest wr)
        {
            wr.Timeout = 15000;

            using (Stream requestStream = wr.GetRequestStream())
            {
                using (FileStream fs = File.OpenRead(filename))
                {
                    int readCount;
                    byte[] buffer = new byte[BUFFER_SIZE];
                    while ((readCount = fs.Read(buffer, 0, buffer.Length)) != 0)
                    {
                        Debug.WriteLine(String.Format("Doing a block, at {0}", fs.Position));
                        requestStream.Write(buffer, 0, readCount);                        
                    }
                    Debug.WriteLine("Finished with input file");
                }
                Debug.WriteLine("Finished with output stream");
            }
        }

        /// <summary>
        /// Gets an XML document as the response from a web request. The response will be <code>null</code>
        /// if it is invalid, either because it is not well-formed XML (e.g. HTML 4.0) or there was
        /// no acceptable response available from the server (e.g. 404)
        /// </summary>
        /// <param name="wr">The web request from which the response should be requested</param>
        /// <returns>The XML document response</returns>
        private XmlDocument GetXmlResponse(HttpWebRequest wr)
        {
            XmlDocument xmlResponse = null;

            try
            {
                using (WebResponse res = wr.GetResponse())
                {
                    using (Stream resStream = res.GetResponseStream())
                    {
                        // when this method was implemented, the SWORD 2 server was still returning HTML:
                        // if (((HttpWebResponse)res).StatusCode == HttpStatusCode.OK)
                        // {
                        //    return null;
                        // }
                        // - so try/catch this in case it changes
                                                    
                        try
                        {
                            xmlResponse = new XmlDocument();
                            xmlResponse.Load(resStream);
                        }
                        catch (XmlException xex)
                        {
                            Debug.WriteLine(xex);
                            // xmlResponse = null; // depends how we want to handle this
                        }
                    }
                }
            }
            catch (WebException wex)
            {
                // likely a 404, write the exception if we're in debug mode, and fall through
                // to return the null response
                Debug.WriteLine(wex);
            }
            return xmlResponse;
        }

        /// <summary>
        /// Deposits the .docx from the supplied filename to the initialised endpoint with the default content type
        /// </summary>
        /// <param name="docxFilename">The filename of the .docx to deposit</param>
        /// <returns>Atom response</returns>
        public string PostDocxToContainer(string docxFilename)
        {
            return this.PostDocxToContainer(docxFilename, DOCX_CONTENTTYPE);
        }

        /// <summary>
        /// Deposits the .docx from the supplied filename to the initialised endpoint with the supplied content type
        /// </summary>
        /// <param name="docxFilename">The filename of the .docx to deposit</param>
        /// <param name="contentType">The content type to use for the deposition</param>
        /// <returns>Atom response</returns>
        public string PostDocxToContainer(string docxFilename, string contentType)
        {
            return this.PostDocxToContainer(docxFilename, contentType, this._endpoint);
        }

        /// <summary>
        /// Deposits the .docx from the supplied filename to the supplied endpoint with the supplied content type
        /// </summary>
        /// <param name="docxFilename">The filename of the .docx to deposit</param>
        /// <param name="contentType">The content type to use for the deposition</param>
        /// <param name="contentUri">The endpoint against which the deposition should occur</param>
        /// <returns>Atom response</returns>
        public string DepositDocxToContents(string docxFilename, string contentType, string contentUri)
        {            
            FileInfo fi = new FileInfo(docxFilename);            
            HttpWebRequest wr = this.GetBasicAuthAtomWebRequest(contentUri);

            wr.Method = "POST";
            wr.Headers.Add("Content-Disposition", "form-data; name=\"" + fi.Name + "\"; filename=\"" + fi.Name + "\"");           
            wr.ContentType = contentType;
            wr.ContentLength = fi.Length;
            // should the default be to extract media, or ignore it?
            wr.Headers.Add("X-Extract-Media", EXTRACT_MEDIA);
            wr.Headers.Add("X-Override-Metadata", "true");
            this.WriteFileToRequest(docxFilename, wr);

            return this.GetResponseLocation(wr); //this.GetXmlResponse(wr);
        }

        /// <summary>
        /// Creates a container on the repository and posts the supplied docx file
        /// to that container
        /// </summary>
        /// <param name="docxFilename">The filename of the docx to post</param>
        /// <param name="contentType">The content type of the docx</param>
        /// <param name="endpoint">The endpoint against which the posting should occur</param>
        /// <returns></returns>
        public string PostDocxToRepository(string docxFilename, string contentType, string endpoint)
        {
            string container = this.CreateContainer(endpoint);
            if (String.IsNullOrEmpty(container))
            {
                return null;
            }

            return this.PostDocxToContainer(docxFilename, contentType);
        }

        /// <summary>
        /// Creates a container on the repository and posts the supplied docx file
        /// to that container, using the default docx content type and the initialised
        /// endpoint on the instance
        /// </summary>
        /// <param name="docxFilename">The filename of the docx to post</param>
        /// <returns></returns>
        public string PostDocxToRepository(string docxFilename)
        {
            string container = this.CreateContainer(this._endpoint);
            if (String.IsNullOrEmpty(container))
            {
                return null;
            }

            return this.PostDocxToContainer(docxFilename, DOCX_CONTENTTYPE, container);
        }

        /// <summary>
        /// Posts the supplied docx file to the supplied container 
        /// </summary>
        /// <param name="docxFilename">The filename of the docx to post</param>
        /// <param name="contentType">The content type of the docx</param>
        /// <param name="containerUri">The URI of the container</param>
        /// <returns></returns>
        public string PostDocxToContainer(string docxFilename, string contentType, string containerUri)
        {
            XmlDocument response = this.GetEprintInfo(containerUri);
            if (response == null) return null;

            SwordAtomReader sar = new SwordAtomReader(response);
            if (sar == null) return null;

            string contentsHref = sar.ContentsHref;
            Debug.WriteLine("Contents href is {0}", contentsHref);
            if (String.IsNullOrEmpty(contentsHref)) return null;

            return this.DepositDocxToContents(docxFilename, contentType, contentsHref);
        }

        /// <summary>
        /// Creates an empty container on the initialised repository
        /// </summary>
        /// <returns>The address of the new empty container</returns>
        public string CreateContainer()
        {
            return this.CreateContainer(this._endpoint);
        }

        /// <summary>
        /// Creates an empty container on the repository at the supplied endpoint
        /// </summary>
        /// <param name="endpoint">The endpoint at which to create the new empty container</param>
        /// <returns>The address of the new empty container</returns>
        public string CreateContainer(string endpoint)
        {
            HttpWebRequest wr = this.GetBasicAuthAtomWebRequest(endpoint);
            wr.Method = "POST";
            wr.ContentType = "application/atom+xml";
            string emptyAtom = @"<?xml version=""1.0"" encoding=""utf-8"" ?>
             <entry xmlns=""http://www.w3.org/2005/Atom"" />";
            wr.ContentLength = (long)emptyAtom.Length;
            
            // TODO: not the most elegant way to write this 'empty' Atom request
            // but functional
            using (Stream requestStream = wr.GetRequestStream())
            {
                foreach (byte b in emptyAtom)
                {
                    requestStream.WriteByte(b);
                }    
            }

            return this.GetResponseLocation(wr);
        }

        /// <summary>
        /// Gets the location of the response from the provided <code>HttpWebRequest</code>
        /// </summary>
        /// <param name="wr">The web request to query</param>
        /// <returns>Location string</returns>
        public string GetResponseLocation(HttpWebRequest wr)
        {
            string location = null;
            using (HttpWebResponse resp = (HttpWebResponse)wr.GetResponse())
            {
                location = resp.Headers[HttpResponseHeader.Location].ToString();
            }
            return location;
        }

        /// <summary>
        /// Gets information about the ePrint at the provided URI
        /// </summary>
        /// <param name="uri">ePrint URI</param>
        /// <returns>Atom XML document</returns>
        public XmlDocument GetEprintInfo(string uri)
        {
            HttpWebRequest wr = this.GetBasicAuthAtomWebRequest(uri);
            wr.Method = "GET";
            return this.GetXmlResponse(wr);
        }

        /// <summary>
        /// Performs a PUT to the supplied endpoint with the supplied document filename using <code>DOCX_CONTENTTYPE</code>.
        /// This will update an existing entry on the SWORD target
        /// </summary>
        /// <param name="documentFileName">The filename of the document to use for the update</param>
        /// <param name="endpoint">The endpoint against which the update should occur</param>
        /// <returns>Atom response</returns>
        public bool PutToDocument(string documentFileName, string endpoint)
        {
            return this.PutToDocument(documentFileName, endpoint, DOCX_CONTENTTYPE);
        }
        
        /// <summary>
        /// Performs a PUT to the supplied endpoint with the supplied document filename using the supplied content type.
        /// This will update an existing entry on the SWORD target
        /// </summary>
        /// <param name="documentFileName">The filename of the document to use for the update</param>
        /// <param name="endpoint">The endpoint against which the update should occur</param>
        /// <param name="contentType">The content type to use for the update</param>
        /// <returns>Atom response</returns>
        public bool PutToDocument(string documentFileName, string endpoint, string contentType)        
        {                     
            HttpWebRequest wr = this.GetBasicAuthAtomWebRequest(endpoint);
            FileInfo fi = new FileInfo(documentFileName);
            wr.Method = "PUT";
            wr.Headers.Add("Content-Disposition", "form-data; name=\"" + fi.Name + "\"; filename=\"" + fi.Name + "\"");            
            wr.ContentType = contentType;
            wr.ContentLength = fi.Length;
            wr.Headers.Add("X-Extract-Media", "true");
            wr.Headers.Add("X-Override-Metadata", "true");
            this.WriteFileToRequest(documentFileName, wr);
            HttpWebResponse response = null;
            try

            {
                response = (HttpWebResponse)wr.GetResponse();
            }
            catch (WebException ex)
            {
                Debug.WriteLine(ex);
                if (ex.Response != null && ex.Response.Headers != null)
                {
                    foreach (HttpResponseHeader h in ex.Response.Headers)
                    {
                        Debug.WriteLine("Header: " + h.ToString());
                    }
                }
            }

            if (response == null) { return false; } 

            bool responseOk = false;
            if (response.StatusCode == HttpStatusCode.OK)
            {
                responseOk = true;
            }            

            if (response != null)
            {
                response.Close();
            }
            return responseOk;            
        }     

        /// <summary>
        /// Deposits the zip file in the supplied filename to the initialised endpoint with
        /// a gzip content type (to be formally standardised at the server side)
        /// </summary>
        /// <param name="zipFileName">The zip filename</param>
        /// <returns>Atom response</returns>
        public XmlDocument DepositZipToEprint(string zipFileName)
        {
            return this.DepositZipToEprint(zipFileName, "application/g-zip");
        }

        /// <summary>
        /// Deposits the zip file in the supplied filename to the initalised endpoint with
        /// the supplied content type
        /// </summary>
        /// <param name="zipFileName">The zip filename</param>
        /// <param name="contentType">The content type</param>
        /// <returns>Atom response</returns>
        public XmlDocument DepositZipToEprint(string zipFileName, string contentType)
        {         
            FileInfo fi = new FileInfo(zipFileName);            
            HttpWebRequest wr = this.GetBasicAuthAtomWebRequest(this._endpoint);
            wr.Method = "POST";            
            wr.Headers.Add("Content-Disposition", "form-data; name=\"" + fi.Name + "\"; filename=\"" + fi.Name + "\"");            
            wr.ContentType = contentType;
            wr.ContentLength = fi.Length;
            wr.Headers.Add("X-Extract-Archive", "true");
            this.WriteFileToRequest(zipFileName, wr);

            return this.GetXmlResponse(wr);
        }

        /// <summary>
        /// Deposits the EP2 XML document to the initialised endpoint with X-Packaging type
        /// <code>EP2_PACKAGING</code>
        /// </summary>
        /// <param name="xmlDocument">The EP2 XML document to deposit</param>
        /// <returns>Atom response</returns>
        public XmlDocument DepositEprintsXml(XmlDocument xmlDocument)
        {
            return this.DepositXml(xmlDocument, EP2_PACKAGING);
        }

        /// <summary>
        /// Deposits the EP2 XML document in the supplied filename to the initialised endpoint
        /// with X-Packaging type <code>EP2_PACKAGING</code>
        /// </summary>
        /// <param name="xmlFileName">The filename of the EP2 XML document to deposit</param>
        /// <returns>Atom response</returns>
        public XmlDocument DepositEprintsXml(string xmlFileName)
        {
            return this.DepositXml(xmlFileName, EP2_PACKAGING);
        }

        /// <summary>
        /// Deposits the XML document in the supplied filename to the initialised endpoint
        /// with the supplied X-Packaging type
        /// </summary>
        /// <param name="xmlFileName">The filename of the XML document to deposit</param>
        /// <param name="xPackaging">The X-Packaging type</param>
        /// <returns>Atom response</returns>
        public XmlDocument DepositXml(string xmlFileName, string xPackaging)
        {
            XmlDocument xmlDocument = new XmlDocument();
            xmlDocument.Load(xmlFileName);
            return this.DepositXml(xmlDocument, xPackaging);
        }

        /// <summary>
        /// Deposits the XML document to the initialised endpoint with the supplied
        /// X-Packaging type
        /// </summary>
        /// <param name="xmlDocument">The XML document to deposit</param>
        /// <param name="xPackaging">The X-Packaging type</param>
        /// <returns>Atom response</returns>
        public XmlDocument DepositXml(XmlDocument xmlDocument, string xPackaging)
        {            
            HttpWebRequest wr = this.GetBasicAuthAtomWebRequest(this._endpoint);            
            wr.Method = "POST";
            wr.Headers.Add("X-Packaging", xPackaging);
            wr.ContentType = "text/xml";

            // note that we can't wrap the Stream here with a using as there
            // is a possibility that Dispose will get called more than once
            // and this will generate an ObjectDisposedException. Instead,
            // we'll not assign the request stream to anything and just
            // pass it through directly

            XmlWriterSettings xws = new XmlWriterSettings();
            xws.CloseOutput = true;            
            
            using (XmlWriter xw = XmlWriter.Create(wr.GetRequestStream(), xws))
            {
                xmlDocument.WriteTo(xw);

                // ensure that the XML writer is flushes as this does *not* happen automatically
                xw.Flush();
            }            
            return this.GetXmlResponse(wr);
        }

        /// <summary>
        /// Deletes the document at the target address <code>swordUrl</code>.
        /// </summary>
        /// <param name="swordUrl">The target address at which the document resides</param>
        /// <returns>Atom response</returns>
        public XmlDocument Delete(string swordUrl)
        {
            HttpWebRequest wr = this.GetBasicAuthAtomWebRequest(swordUrl);
            wr.Method = "DELETE";
            return this.GetXmlResponse(wr);
        }

        /// <summary>
        /// List all records at the endpoint
        /// </summary>
        /// <param name="stripEndpoint"><code>true</code> if the endpoint should be stripped down
        /// and the default of /id/records (<code>LIST_RECORD_PATH</code>) used, else <code>false</code> 
        /// if the literal endpoint, suffixed with /id/records (<code>LIST_RECORD_PATH</code>) 
        /// value should be used</param>
        /// <returns>List of records in XML format, else <code>null</code></returns>
        /// <exception cref="WebException">Typically thrown at a timeout on the endpoint</exception>
        public XmlDocument ListRecords(bool stripEndpoint)
        {
            string target = this._endpoint;

            HttpWebRequest initialWr = null;
            HttpWebRequest realWr = null;
            WebResponse wresp = null;
            XmlDocument xmlDocument = null;

            if (stripEndpoint)
            {
                target = new Uri(this._endpoint).GetLeftPart(UriPartial.Authority);
            }
            string records = target + LIST_RECORD_PATH;
             
            Debug.WriteLine("Requesting records from " + records);
            initialWr = this.GetBasicAuthAtomWebRequest(records);
            initialWr.Method = "GET";
            
            try
            {
                wresp = initialWr.GetResponse();
            }
            catch (WebException wex)
            {
                // if we've timed out, rethrow the exception
                if (wex.Status == WebExceptionStatus.Timeout)
                {
                    throw wex;
                }

                // being forced to handle exceptions as part of normal program control
                // is not pleasant (303 in this case)
                Debug.WriteLine(wex.Response.ResponseUri);
                Uri realUri = wex.Response.ResponseUri;
                realWr = this.GetBasicAuthAtomWebRequest(realUri);
                realWr.Method = "GET";
                wresp = realWr.GetResponse();
            }            
            
            using (Stream resStream = wresp.GetResponseStream())
            {
                try
                {
                    xmlDocument = new XmlDocument();
                    xmlDocument.Load(resStream);
                }
                catch (XmlException xex)
                {
                    Debug.WriteLine(xex);
                }
            }            

            if (wresp != null)
            {
                wresp.Close();
            }

            return xmlDocument;
        }
        
        /// <summary>
        /// List all records at the endpoint, by calling endpoint/id/records (<code>LIST_RECORD_PATH</code>)
        /// </summary>
        /// <returns>List of records in XML format, else <code>null</code></returns>
        /// <exception cref="WebException">Typically thrown at a timeout on the endpoint</exception>
        public XmlDocument ListRecords()
        {
            return this.ListRecords(false);
        }
    }
}
