<?xml version='1.0'?>

<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'>

<xsl:output method='xml' indent='yes' encoding='utf-8'/>

<xsl:template match='/'>
<records>
<xsl:apply-templates select='/RECORDS/REC'/>
</records>
</xsl:template>

<xsl:template match='REC'>
<dc>
<xsl:attribute name='recid'><xsl:value-of select='@recid'/></xsl:attribute>
<xsl:for-each select='./item/authors/primaryauthor|./item/authors/author'>
<xsl:choose>
<xsl:when test="name(./following-sibling::*[1])='fullauthorname'">
<xsl:for-each select="./following-sibling::*[1]">
<creator><xsl:value-of select='./AuLastName'/>, <xsl:value-of select='./AuFirstName'/></creator>
<creator.address>
<xsl:value-of select='./address'/>
</creator.address>
</xsl:for-each>
</xsl:when>
<xsl:otherwise>
<creator><xsl:value-of select='.'/></creator>
</xsl:otherwise>
</xsl:choose>
</xsl:for-each>
<title><xsl:value-of select='./item/item_title' /></title>
<date><xsl:value-of select='./item/bib_issue/@year' /></date>
</dc>
</xsl:template>

</xsl:stylesheet>
