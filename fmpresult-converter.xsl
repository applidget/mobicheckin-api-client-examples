<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:template match="guests">
<FMPXMLRESULT xmlns="http://www.filemaker.com/fmpxmlresult">
    <DATABASE DATEFORMAT="MM/dd/yy" TIMEFORMAT="hh:mm:ss"/>
    <METADATA>
    <xsl:for-each select="guest[1]/*">
        <FIELD>
            <xsl:attribute name="NAME">
                <xsl:value-of select="name(.)"/>
            </xsl:attribute>
           
            <xsl:attribute name="TYPE">
                <xsl:value-of select="'TEXT'"/>
            </xsl:attribute>
        </FIELD>
    </xsl:for-each>
    </METADATA>
    <xsl:variable name="nb" select="count(//uid)"/>
    <RESULTSET FOUND="{$nb}">
    <xsl:for-each select="guest">
        <ROW>
           <xsl:choose>
               <xsl:when test="name(.)='access-privileges'">
                </xsl:when>
                <xsl:when test="name(.)='guest-metadata'">
                </xsl:when>
               <xsl:otherwise>
                    <xsl:for-each select="*">
                    <COL><DATA><xsl:value-of select="."/></DATA></COL>
                    </xsl:for-each>
                </xsl:otherwise>
            </xsl:choose>
       </ROW>
    </xsl:for-each>
    </RESULTSET>
</FMPXMLRESULT>
</xsl:template>

</xsl:stylesheet>
