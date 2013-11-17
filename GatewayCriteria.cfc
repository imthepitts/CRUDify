component accessors="true"  {

    property name="criteria" type="struct";

    variables.criteria = {}; 
    
    public any function init(struct criteria={}){
        return parseCriteria(criteria);
    }    
    
    public any function also(required struct criteria){
        return parseCriteria(criteria, 'AND');
    }

    public any function either(required struct criteria){
        return parseCriteria(criteria, 'OR');
    }

    public any function done(){
        return variables.criteria;
    }

    public void function addCriteria(required string field, required string value, string comparison='=', string logic='AND'){
        param name="variables.criteria.#logic#" default="#[]#";
        arrayAppend(variables.criteria[logic], {field=arguments.field, value=arguments.value, comparison=comparison});
    }

    private any function parseCriteria(required struct criteria, string logic='AND'){
        if (isObject(criteria)){
            criteria = criteria.getCriteria();
        }
        if (structIsEmpty(criteria)){
            return this;
        }
        if (structKeyExists(criteria, 'field')){
            structAppend(criteria, {value='', comparison='=', logic=logic}, false);
            addCriteria(argumentCollection=criteria);
            return this;
        }
        for (var param in criteria){            
            if (structKeyExists(criteria, 'AND') || structKeyExists(criteria, 'OR')){
                param name="variables.criteria.#logic#" default="#[]#";
                arrayAppend(variables.criteria[logic], criteria);
            }
            if (isSimpleValue(criteria[param]) && !listFindNoCase('field,value,comparison', param)){
                addCriteria(param, criteria[param], '=');
                structDelete(criteria, param);
            } else if (isStruct(criteria[param])){
                var criterion = criteria[param];
                structAppend(criterion, {field=param, value='', comparison='=', logic=logic}, false);
                addCriteria(argumentCollection=criterion);
                structDelete(criteria, param);
            }
        }
        return this;
    }    
}