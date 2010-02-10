<?xml version='1.0'?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="http://eprints.org/ep2/data/2.0">

<xsl:output method="xml" indent="yes" />

<xsl:template match="text()" />
<xsl:template match="@*" />

<xsl:template match="/">
<eprints>
<xsl:apply-templates select="RECORDS/REC" />
</eprints>
</xsl:template>

<xsl:template match="REC">
<eprint>
<status>published</status>
<xsl:apply-templates select="item/*|item/*/@*" />
</eprint>
</xsl:template>

<xsl:template match="item/source_title">
<publication><xsl:value-of select="."/></publication>
</xsl:template>

<xsl:template match="item/item_title">
<title><xsl:value-of select="."/></title>
</xsl:template>

<xsl:template match="item/bib_pages">
<pagerange><xsl:value-of select="."/></pagerange>
</xsl:template>

<xsl:template match="item/bib_pages/@pages">
<pages><xsl:value-of select="."/></pages>
</xsl:template>

<xsl:template match="item/bib_issue/@vol">
<volume><xsl:value-of select="."/></volume>
</xsl:template>

<xsl:template match="item/bib_issue/@year">
<date><xsl:value-of select="."/></date>
</xsl:template>

<xsl:template match="item/doctype/@code">
<xsl:choose>
<xsl:when test=".='@'">
<type>article</type>
</xsl:when>
<xsl:otherwise>
<type>article</type>
</xsl:otherwise>
</xsl:choose>
</xsl:template>

<xsl:template match="item/authors">
<creators>
<xsl:choose>
<xsl:when test="fullauthorname">
<xsl:apply-templates select="fullauthorname" />
</xsl:when>
<xsl:otherwise>
<xsl:apply-templates select="primaryauthor | author" />
</xsl:otherwise>
</xsl:choose>
</creators>
</xsl:template>

<xsl:template match="item/authors/primaryauthor|item/authors/author">
<item>
<name>
<family><xsl:value-of select="substring-before(.,',')" /></family>
<given><xsl:value-of select="substring-after(.,', ')" /></given>
</name>
</item>
</xsl:template>

<xsl:template match="item/authors/fullauthorname">
<item>
<name>
<family><xsl:value-of select="AuLastName" /></family>
<given><xsl:value-of select="AuFirstName" /></given>
</name>
</item>
</xsl:template>

<xsl:template match="item/abstract">
<abstract><xsl:value-of select="." /></abstract>
</xsl:template>

<xsl:template match="item/article_nos/article_no[substring(.,1,3)='DOI'][last()]">
<id_number><xsl:value-of select="substring-after(.,'DOI ')" /></id_number>
</xsl:template>

</xsl:stylesheet>
