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
using System.Net;
using System.IO;
using System.Diagnostics;

namespace uk.ac.soton.ses
{
    /// <summary>
    /// Limited basic HTML parsing routines
    /// </summary>
    public class HtmlScraper
    {
        /// <summary>
        /// Returns the content metatag value for the supplied parameter name and web address
        /// </summary>
        /// <param name="address">Web address containing HTML to be parsed</param>
        /// <param name="name">Name of the content parameter</param>
        /// <returns></returns>
        public static string GetMetaContent(string address, string name)
        {
            return GetMetaContent(address, name, "content");
        }

        /// <summary>
        /// Returns the value of the named attribute from a metatag if this exists
        /// </summary>
        /// <param name="address">Web address containing HTML to be parsed</param>
        /// <param name="name">Name of the content parameter (e.g. foo if name="foo")</param>
        /// <param name="target">Name of the target attribute (e.g. value if value="bar")</param>
        /// <returns>Value of the target attribute (e.g. bar if value="bar")</returns>
        public static string GetMetaContent(string address, string name, string target)
        {
            return GetAttributeContent((HttpWebRequest)HttpWebRequest.Create(address), "meta", "name", name, target);
        }

        /// <summary>
        /// Returns the value of the named attribute from the supplied address. For example, given:
        /// 
        /// link rel="foo" href="bar"
        /// </summary>
        /// <param name="address">Web address containing HTML to be parsed</param>
        /// <param name="type">Type of tag, e.g. link</param>
        /// <param name="namelabel">Label of the name, e.g. rel</param>
        /// <param name="name">Name, e.g. foo</param>
        /// <param name="target">Target label, e.g. href</param>
        /// <returns>Target value, e.g. bar</returns>
        public static string GetAttributeContent(string address, string type, string namelabel, string name, string target)
        {
            return GetAttributeContent((HttpWebRequest)HttpWebRequest.Create(address), type, namelabel, name, target);
        }

        /// <summary>
        /// Gathers values from an HTML file's attribute where another named attribute matches another value. For example, given:
        /// 
        ///  link rel="foo" href="bar"
        ///  
        /// as HTML content from http://www.example.com, one can retrieve the value 'bar' by calling:
        /// 
        /// GetAttributeContent((HttpWebRequest)HttpWebRequest.Create("http://www.example.com"), "link", "rel", "foo", "href").
        /// 
        /// Note that this method hasn't been exhaustively tested but appears to work fairly well even for relatively broken
        /// HTML 4 documents (as well as nice, strict XHTML ones). Additionally, as the whole HTML document is loaded into
        /// RAM whilst parsing (in order to ditch and close the request/responses early) a truly massive HTML document
        /// *could* cause a <code>OutOfMemoryException</code>.
        /// 
        /// All exceptions are caught, outputted to any debug listener, and rethrown
        /// 
        /// It is not optimised and could contain bugs, so please use with caution!
        /// </summary>
        /// <param name="request">The HTTP web request from which to gather an HTML response</param>
        /// <param name="type">The type of tag (e.g. "meta" or "link")</param>
        /// <param name="namelabel">The label of the tag to match</param>
        /// <param name="name">The value of the labelled tag to match</param>
        /// <param name="target">The label of the target tag</param>
        /// <returns>The value of the target tag</returns>
        public static string GetAttributeContent(HttpWebRequest request, string type, string namelabel, string name, string target)
        {
            string contentvalue = null;
            string responsestring = null;

            // return early if the input is bad
            if (type == null || namelabel == null || name == null || target == null || request == null)
            {
                return null;
            }

            string targettagtype = type.ToLower();
            string targetnamelabel = namelabel.ToLower();

            try
            {
                // first, get the page code into a string for parsing                
                using (HttpWebResponse resp = (HttpWebResponse)request.GetResponse())
                {
                    using (TextReader tr = new StreamReader(resp.GetResponseStream()))
                    {
                        responsestring = tr.ReadToEnd();
                    }
                }

                // request doesn't close and response should be already closed

                for (int l = 0; l < responsestring.Length - targettagtype.Length; l++)
                {
                    // do we have an opening tag?
                    if (responsestring[l].Equals('<'))
                    {
                        // gather the substring to see if this tag is a meta
                        string substring = responsestring.Substring(l, targettagtype.Length + 1);
                        if (substring.ToLower().Equals("<" + targettagtype))
                        {
                            // find end
                            int endpoint = -1;
                            for (int e = l; e < responsestring.Length; e++)
                            {
                                if (responsestring[e].Equals('>'))
                                {
                                    endpoint = e;
                                    break;
                                }
                            }

                            // we successfully found the end of the meta line(s)
                            if (endpoint > -1)
                            {
                                // isolate this meta line
                                string metaline = responsestring.Substring(l, endpoint - l + 1);

                                // find the 'name' part
                                int nameIndex = metaline.ToLower().IndexOf(" " + targetnamelabel);
                                if (nameIndex > -1)
                                {
                                    int startchar = -1;
                                    int endchar = -1;
                                    for (int i = nameIndex; i < metaline.Length; i++)
                                    {
                                        if (metaline[i] == '"' || metaline[i] == '\'')
                                        {
                                            if (startchar == -1)
                                            {
                                                startchar = i;
                                            }
                                            else
                                            {
                                                endchar = i;
                                            }
                                        }

                                        if (startchar > -1 && endchar > -1)
                                        {
                                            break;
                                        }
                                    }

                                    // this should be the name of the meta tag
                                    string namevalue = metaline.Substring(startchar + 1, endchar - (startchar + 1));
                                    Debug.WriteLine(String.Format("Found tag type {0} with name {1}", targetnamelabel, namevalue));

                                    // is it the one we want?
                                    if (namevalue.ToLower().Equals(name.ToLower()))
                                    {
                                        Debug.WriteLine(String.Format("Correct line found: {0}", metaline));

                                        int contentstart = -1;
                                        int contentend = -1;
                                        int contentindex = -1;

                                        // ok, now look for the attribute we want the value for inside this meta
                                        contentindex = metaline.IndexOf(" " + target);
                                        if (contentindex > -1)
                                        {
                                            for (int i = contentindex; i < metaline.Length; i++)
                                            {
                                                if (metaline[i] == '"' || metaline[i] == '\'')
                                                {
                                                    if (contentstart == -1)
                                                    {
                                                        contentstart = i;
                                                    }
                                                    else
                                                    {
                                                        contentend = i;
                                                    }
                                                }

                                                if (contentstart > -1 && contentend > -1)
                                                {
                                                    break;
                                                }
                                            }

                                            if (contentstart != -1 && contentend != -1)
                                            {
                                                // match found for the contents of the attribute
                                                contentvalue = metaline.Substring(contentstart + 1, contentend - (contentstart + 1));
                                                Debug.WriteLine(String.Format("Content value is {0}", contentvalue));
                                                break;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Debug.WriteLine(ex);
                throw ex;
            }

            return contentvalue == null ? null : contentvalue.Trim();
        }
    }
}
