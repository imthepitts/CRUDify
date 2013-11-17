component extends='WEB-INF.cfusion.CustomTags.com.adobe.coldfusion.query' accessors='true' {

    property string tableName;
    property string alias;
    property string joins;
    property struct criteria;
    property array columns;
    property string sort;
    property struct pagination;
    property boolean distinct;
        
    public any function init(required string tableName, struct criteria={}, any columns='*', string sort='', struct pagination={}){
        structAppend(variables, arguments);
        variables.criteria = duplicate(arguments.criteria);
        variables.sql = '';
        variables.joins = '';
        variables.alias = 't1';
        variables.columns = prefixColumns(variables.columns);
        variables.distinct = false;
        variables.parentLogic = '';
        if (variables.columns[1] == 'COUNT(*) AS COUNT'){
            variables.sort = '';
        }
        if (isObject(variables.criteria)){
            variables.criteria = variables.criteria.getCriteria();
        } else {
            variables.criteria = new GatewayCriteria(variables.criteria).getCriteria();
        }
        return this;
    }
    
    public void function joinTable(required string tableName, required string alias, required string joinCriteria, string joinType='INNER'){
        var joinedSql = arguments.joinType & ' JOIN ' & arguments.tableName & ' ' & arguments.alias & ' ON ';
        arguments.joinCriteria = listToArray(arguments.joinCriteria);
        joinedSql &= '0=0 ';
        for (var condition in arguments.joinCriteria){
            joinedSql &= 'AND ' & condition & ' ';
        }
        variables.joins &= joinedSql & ' ';
    }

    public void function addCriteria(required string param, required string value, string comparison='=', string logic='AND'){
        arrayAppend(variables.criteria[logic], {'field'=arguments.param, 'value'=arguments.value, 'comparison'=comparison});
    }
    
    public void function addColumn(required string column){
        arrayAppend(variables.columns, arguments.column);
    }
    
    public void function appendSql(required string sql){
        variables.sql = listAppend(variables.sql, arguments.sql, ' ');
    }
    

    public any function bind(string sql){
        appendSql(getBaseSql());
        if (isNull(arguments.sql)){
            appendSql('WHERE 0=0 ');
            parseCriteria();            
        } else {
            appendSql(arguments.sql);
        }
        if (!structIsEmpty(pagination)){
            variables.sql = paginate(variables.sql);
        }
        else if (len(sort)){
            appendSql('ORDER BY ' & sort);  
        }
        return this;
    }
    
    public struct function execute(){
        var result = super.execute();
        attachTotalResults(result);
        attachQueryUtils(result);
        return result;
    }
        
    public string function getBaseSql(){
        return 'SELECT #((variables.distinct) ? 'DISTINCT' : '')# ' & arrayToList(variables.columns) & ' FROM ' & variables.tableName & ' ' & variables.alias  & ' ' & variables.joins;
    }

    private string function paginate(required string sql){
        addParam(name='start', value=variables.pagination.offset+1);
        addParam(name='end', value=variables.pagination.limit+variables.pagination.offset);
        return '
            WITH Pagination AS (
                SELECT #((variables.distinct) ? 'DISTINCT' : '')# *, ROW_NUMBER() OVER (ORDER BY #variables.sort#) AS rowNumber 
                FROM ( 
                    #arguments.sql#
                ) #variables.tableName#
            )
            SELECT *, 
                (SELECT COUNT(*) FROM Pagination) AS totalResults
            FROM Pagination
            WHERE rowNumber 
                BETWEEN :start   
                AND :end 
            ORDER BY rowNumber
        ';      
    }   

    private void function attachTotalResults(required any result){
        var recordSet = result.getResult();
        var meta = result.getPrefix();
        if (isNull(recordSet.totalResults)){
            meta.totalResults = meta.recordCount;
        }
        else {
            meta.totalResults = recordSet.totalResults;
        }
    }
    
    private void function attachQueryUtils(required any result){
        result.toArray = this.toArray;
        result.toStruct = this.toStruct;
    }
    
    private array function prefixColumns(required any columns){
        if (!isArray(columns)){
            columns = listToArray(columns);
        }
        for (var i = 1; i <= arrayLen(columns); i++){
            if (columns[i] does not contain ' AS '){
                columns[i] = variables.alias & '.' & trim(columns[i]);              
            }
        }
        return columns;
    }
    
    private void function parseCriteria(struct criteria=variables.criteria, string parentLogic){
        var switchLogic = false;
        if (!isNull(parentLogic) || parentLogic != variables.parentLogic){
            variables.parentLogic = parentLogic;
        } else {
            var switchLogic = true;
        }
        for (var logic in criteria){
            if (switchLogic){
                variables.parentLogic = logic;
            }
            if (isArray(criteria[logic]) && arrayLen(criteria[logic])){
                parseCriteriaArray(criteria[logic], logic.toUpperCase());
            }
        }   
    }
    
    private void function parseCriteriaArray(required array criteria, required string logic){
        if (!len(variables.parentLogic)){
            variables.parentLogic = logic;
        }
        appendSql('#variables.parentLogic# ( 0=' & 3-len(logic));
        for (var item in criteria){
            if (structKeyExists(item, 'AND') || structKeyExists(item, 'OR')){
                parseCriteria(item, logic);
            } else {
                var paramName = item.field & createUUID();
                param name="item.value" default="";
                addParam(name=paramName, value=item.value, list=item.comparison == 'IN');
                if (item.comparison contains 'NULL'){
                    appendSql('#logic# ' & item.field & ' #item.comparison# ');
                } else {
                    appendSql('#logic# ' & item.field & ' #item.comparison# (:' & paramName & ') ');
                }
            }
        }
        appendSql(')');
    }

    public struct function toStruct(numeric rowNumber=1){
        var query = this.getResult();
        var struct = {};
        var columns = query.getMeta().getColumnLabels();
        for (var i = 1; i <= arrayLen(columns); i++){
            struct[columns[i]] = query[columns[i]][arguments.rowNumber];
        }        
        return struct;
    }
    
    public array function toArray(){
        var query = this.getResult();
        var result = [];
        for (var i = 1; i <= query.recordCount; i++){
            arrayAppend(result, this.toStruct(i));
        }
        return result;
    }


}