import java.io.*;
import java.util.*;
import java.text.*;

class ProcessChangelog {

	public static void main(String[] args) {
		try {
			ProcessChangelog pc = new ProcessChangelog(args[0],args[1]);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	public ProcessChangelog(String target, String changes) throws Exception {
		BufferedReader in = new BufferedReader(new FileReader(changes));
		String line;
		String current_author = "";
		String change = "";
		Hashtable contributors = getContributors();
		Hashtable lines = new Hashtable();
		while ((line = in.readLine()) != null) {
			line = line.trim();
			if (line.substring(0,1).equals(">")) {
				line = line.substring(1,line.length()).trim();
				//System.out.println(line);
				try {
					if (line.substring(4,5).equals("-") && line.substring(7,8).equals("-")) {
						try {
							if (!change.equals("")) {
								String temp = (String)lines.get(current_author);
								try {
									if (!temp.equals("")) {
										temp += "\n" + change;
									}
								} catch (Exception e) {
									temp = "" + change;
								}
								//System.out.println(current_author + " ADDING " + temp);
								lines.put(current_author,temp);
								change = "";
							}
						} catch (Exception e) {
							e.printStackTrace();
						}
						current_author = line.substring(10,line.length()).trim();
					} else if(line.equals("") || line.substring(0,1).equals("=") || line.substring(0,7).equals("EPRINTS")) {
					} else if(!line.substring(0,1).equals("*")) {
						change += " " + line.trim();
					} else if(line.substring(0,1).equals("*")) {
						try {
							if (!change.equals("")) {
								String temp = (String)lines.get(current_author);
								try {
									if (!temp.equals("")) {
										temp += "\n" + change;
									}
								} catch (Exception e) {
									temp = "" + change;
								}
								//System.out.println(current_author + " ADDING " + temp);
								lines.put(current_author,temp);	
								change = "";
							} 
						} catch (Exception e) {
						}
						change = "  * " + line.substring(1,line.length()).trim();
					} else {
						System.out.println("Failed: " + line);
					}
				} catch (Exception e) {
				}
			}
		}
		in.close();
		try {
			BufferedWriter out = new BufferedWriter(new FileWriter("changes.txt"));
			String target_version = target.replace("eprints-","");
			out.write("eprints (" + target_version + ") unstable; urgency=low");
			out.newLine();
			for (Enumeration keys=contributors.keys(); keys.hasMoreElements();) {
				current_author = (String)keys.nextElement();
				String author_lines = "";
				try {
					author_lines = (String)lines.get(current_author);
					if (!author_lines.equals("")) {
						out.write("  [" + contributors.get(current_author) + "]");
						out.newLine();
						out.write(author_lines);
						out.newLine();
						out.newLine();
					}
				} catch (Exception e) {
				}
			}
			Date now = new Date();
			SimpleDateFormat sdf = new SimpleDateFormat("EEE, d MMM yyyy HH:mm:ss Z");
			String formatted = sdf.format(now);
			out.write(" -- David Tarrant <dct05r@ecs.soton.ac.uk>  " + formatted);
			out.newLine();
			out.newLine();
			out.close();
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	public Hashtable getContributors() {
		Hashtable contributors = new Hashtable();
		contributors.put("cjg","Christopher Gutteridge");
		contributors.put("tmb","Timothy Miles-Board");
		contributors.put("tdb","Tim Brody");
		contributors.put("dct05r","David Tarrant");
		return contributors;
	}

}
