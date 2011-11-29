Build instructions for DepositMO Word 2010 author add-in
========================================================

Requirements:

- Microsoft Visual Studio 2010
- Microsoft Office 2010
- Microsoft .NET Framework v4.0

Open a Visual Studio x64 Command Prompt.

Change directory to the Word2010DepositMOAddIn subdirectory.

Enter the following command at the command prompt:

  msbuild Word2010DepositMOAddIn.sln \
    /p:Configuration=Release /p:Platform="Any CPU"

This will build both the SWORD handler library and the Microsoft
Word plug-in.

The output can then be found in the bin\Release subdirectory.

