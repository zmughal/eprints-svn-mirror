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
using System.Diagnostics;
using System.Threading;

namespace uk.ac.soton.ses
{
    /// <summary>
    /// A series of basic tests for the .NET API
    /// </summary>
    internal class SwordClientHandlerTests
    {
        string sword2User = null;
        string sword2Password = null;
        string sword2Endpoint = null;

        internal string EPRINT_TO_DELETE = "http://depositmo.eprints.org/id/eprint/58";

        XmlWriterSettings xws = new XmlWriterSettings();
        XmlWriter consoleWriter = null;
        XmlDocument response = null;

        public SwordClientHandlerTests(string sword2User, string sword2Password, string sword2Endpoint)
        {
            this.sword2User = sword2User;
            this.sword2Password = sword2Password;
            this.sword2Endpoint = sword2Endpoint;
            this.xws.Indent = true;
            this.consoleWriter = XmlWriter.Create(Console.Out, this.xws);
        }

        public void Run()
        {
            bool runAllTests = false;
            bool testPutToDocument = true;
            bool testDepositZipToEprint = false;
            bool testDepositEprintsXml = false;
            bool testAtomReader = false;
            bool testDelete = false;
            bool testList = false;
            bool testResolveInbox = false;
            bool testGetInfo = false;
            bool testCreateContainer = false;
            bool testPutOnly = false;

            SwordClientHandler sword2Handler = new SwordClientHandler(this.sword2User, this.sword2Password, this.sword2Endpoint);

            if (testResolveInbox || runAllTests)
            {
                this.TestResolveInbox(sword2Handler);
            }

            if (testAtomReader || runAllTests)
            {
                this.TestAtomReader();
            }

            if (testDelete || runAllTests)
            {
                this.TestDelete(sword2Handler, EPRINT_TO_DELETE);
            }

            if (testDepositZipToEprint || runAllTests)
            {
                this.TestDepositZipToEprint(sword2Handler);
            }
            
            if (testPutToDocument || runAllTests)
            {
                TestPutToDocument(sword2Handler);
            }

            if (testDepositEprintsXml || runAllTests)
            {
                this.TestDepositEprintsXml(sword2Handler);
            }

            if (testList || runAllTests)
            {
                this.TestList(sword2Handler);
            }

            if (testGetInfo || runAllTests)
            {
                this.TestGetInfo(sword2Handler);            
            }

            if (testCreateContainer || runAllTests)
            {
                this.TestCreateContainer(sword2Handler);
            }

            if (testPutOnly)
            {
                this.TestPutOnly(sword2Handler);
            }

            if (this.response != null)
            {
                response.WriteTo(consoleWriter);
                consoleWriter.Flush();
            }
        }

        private void TestDelete(SwordClientHandler sword2Handler, string targetToDelete)
        {
            Debug.WriteLine(String.Format("Deleting document at {0}", targetToDelete));
            XmlDocument atomResponse = sword2Handler.Delete(targetToDelete);
            Debug.WriteLine("Finished deletion test");
        }

        private void TestPutOnly(SwordClientHandler sword2Handler)
        {
            bool result = sword2Handler.PutToDocument(@"P:\tmp\hyb.docx", "http://depositmo.eprints.org/id/document/1736664");//"http://depositmo.eprints.org/id/document/1736641");
            return;
        }

        private void TestPutToDocument(SwordClientHandler sword2Handler)
        {
            Debug.WriteLine("Depositing new .docx");
            //XmlDocument atomResponse = sword2Handler.DepositDocxToEprint(@"P:\tmp\hy.docx");
            string locationHeader = sword2Handler.PostDocxToRepository(@"P:\tmp\hy.docx");
         
            Debug.WriteLine("Initialising Atom response reader");
           /*
            SwordAtomReader sar = new SwordAtomReader(atomResponse);
            
            Debug.WriteLine("Title was " + sar.AtomTitle);
            Debug.WriteLine("Edit media href is " + sar.EditMediaHref);
            Debug.WriteLine("Contents href is " + sar.ContentsHref);*/
            /*
            XmlDocument dereference = sword2Handler.GetAtomXml(sar.EditMediaHref);
            XmlDocument subdocument = new XmlDocument();
            XmlNamespaceManager xmlns = new XmlNamespaceManager(dereference.NameTable);
            //xmlns.AddNamespace("default", "");
            //xmlns.AddNamespace("atom", "http://www.w3.org/2005/Atom");
            xmlns.AddNamespace(String.Empty, "http://www.w3.org/2005/Atom");
            subdocument.AppendChild(dereference.SelectSingleNode("//feed", xmlns));
            SwordAtomReader sar2 = new SwordAtomReader(subdocument);
            */
            

            Debug.WriteLine("Attempting to update document after a few seconds ...");
            Thread.Sleep(30 * 1000);
            //bool result = sword2Handler.PutToDocument(@"P:\tmp\hyb.docx", sar.EditMediaHref);
            bool result = sword2Handler.PutToDocument(@"P:\tmp\hyb.docx", locationHeader); //sar.ContentsHref);
            
            // note that until at least 15th December 2010, this response is not Atom XML so
            // the following is/was not valid. However, the update to the title was occurring
            
            Debug.WriteLine("Update result: " + result.ToString());
        }

        private void TestResolveInbox(SwordClientHandler sword2Handler)
        {
            bool origvalue = sword2Handler._resolveInbox;
            sword2Handler._resolveInbox = true;
            sword2Handler.ResolveInbox();
            // leave things as we found them
            sword2Handler._resolveInbox = origvalue;
        }

        private void TestDepositZipToEprint(SwordClientHandler sword2Handler)
        {
            Debug.WriteLine("Depositing zip file");
            this.response = sword2Handler.DepositZipToEprint(@"P:\tmp\depositmo_sword2_test_scripts\pics.tar.gz");
            SwordAtomReader sar = new SwordAtomReader(this.response);
            Debug.WriteLine("ID was " + sar.AtomId);
        }        

        private void TestDepositEprintsXml(SwordClientHandler sword2Handler)
        {
            Debug.WriteLine("Depositing XML file");
            XmlDocument xmlDocument = new XmlDocument();
            xmlDocument.Load(@"P:\tmp\depositmo_sword2_test_scripts\test-import.xml");
            this.response = sword2Handler.DepositEprintsXml(xmlDocument);
            SwordAtomReader sar = new SwordAtomReader(this.response);
            Debug.WriteLine("ID was " + sar.AtomId);
        }

        private void TestGetInfo(SwordClientHandler sword2Handler)
        {
            this.response = sword2Handler.GetEprintInfo("http://bazaar.eprints.org/id/eprint/23");
            SwordAtomReader sar = new SwordAtomReader(this.response);
            Console.WriteLine("Atom title is {0}", sar.AtomTitle);
            Console.WriteLine("Contents href is {0}", sar.ContentsHref);

            Debug.WriteLine("Got info!");
        }

        private void TestList(SwordClientHandler sword2Handler)
        {
            Debug.WriteLine("Retrieving listing");
            //XmlDocument xmlDocument = new XmlDocument();
            //this.response = sword2Handler.ListRecords();
            //Uri uri = new Uri("http://yomiko.ecs.soton.ac.uk:8027/more/parts/to/this/");
            //string leftPart = uri.GetLeftPart(UriPartial.Authority);

            //XmlReader xr = XmlTextReader.Create(@"C:\listresults.xml");
            //this.response = new XmlDocument();
            //this.response.Load(@"C:\listresults.xml");
            //SwordListReader slr2 = new SwordListReader(this.response);

            //return;

            this.response = sword2Handler.ListRecords(true);
            //this.response.WriteTo(this.consoleWriter);

            SwordListReader slr = new SwordListReader(this.response);
            
            //XmlWriter xw=XmlTextWriter.Create(@"C:\listresults.xml");
            //this.response.WriteTo(xw);
            //xw.Close();

            foreach (SwordListEntry sle in slr.Entries)
            {
                Console.WriteLine("Title: " + sle.Title);
            }

            this.consoleWriter.Flush();
            Console.Out.Flush();
            Console.ReadKey();
        }

        private void TestAtomReader()
        {
            XmlDocument atomResponse = new XmlDocument();
            //atomResponse.LoadXml(@"<?xml version=""1.0"" encoding=""UTF-8""?><atom:entry xmlns:atom=""http://www.w3.org/2005/Atom"" xmlns:sword=""http://purl.org/net/sword/"">  <atom:title>On Testing the Atom Protocol...</atom:title>  <atom:id>http://depositmo.eprints.org/id/eprint/40</atom:id>  <atom:updated>2010-11-04T05:35:21Z</atom:updated>  <atom:published>2006-10-25T00:45:02Z</atom:published>  <atom:author>    <atom:name>admin</atom:name>    <atom:email>davetaz@ecs.soton.ac.uk</atom:email>  </atom:author>  <atom:summary type=""text"" />  <atom:content type=""text/xml"" src=""http://depositmo.eprints.org/id/document/206"" />  <atom:link rel=""edit-media"" href=""http://depositmo.eprints.org/id/document/206"" />  <atom:link rel=""edit"" href=""http://depositmo.eprints.org/sword-app/atom/40.atom"" />  <atom:generator uri=""http://depositmo.eprints.org"" version=""1.3"">DepositMO / SWORD 2 Endpoint [eprints-build-2010-11-26-r5991]</atom:generator>  <sword:treatment>Deposited items will remain in your user inbox until you manually send them for reviewing.</sword:treatment>  <sword:packaging>http://eprints.org/ep2/data/2.0</sword:packaging>  <sword:noOp>false</sword:noOp></atom:entry>");
            atomResponse.LoadXml(@"<entry>
  <title>A magical and modified document</title>
  <link rel=""self"" href=""http://depositmo.eprints.org/cgi/export/eprint/311/Atom/depositmo-eprint-311.xml""/>
  <link rel=""edit"" href=""http://depositmo.eprints.org/id/eprint/311""/>
  <link rel=""edit-media"" href=""http://depositmo.eprints.org/id/eprint/311/contents""/>
  <link rel=""alternate"" href=""http://depositmo.eprints.org/id/eprint/311""/>
  <summary>Q., Hercules (2011) A magical and modified document.</summary>
  <updated>2011-03-03T08:01:37Z</updated>
  <id>http://depositmo.eprints.org/id/eprint/311</id>
  <category term=""article"" scheme=""http://depositmo.eprints.org/data/eprint#type""/>
  <author>
    <name>Hercules Q.</name>
  </author>
</entry>
");

            XmlWriterSettings xws = new XmlWriterSettings();
            xws.Indent = true;
            XmlWriter xw = XmlWriter.Create(Console.Out);
            atomResponse.WriteTo(xw);
            xw.Flush();

            SwordAtomReader sar = new SwordAtomReader(atomResponse);
            Console.WriteLine("EditMediaHref: " + sar.EditMediaHref);
            Console.WriteLine("EditHref: " + sar.EditHref);
            Console.WriteLine("AtomId: " + sar.AtomId);
        }

        private void TestCreateContainer(SwordClientHandler sword2Handler)
        {
            string response = sword2Handler.CreateContainer();
            return;
        }
    }
}
