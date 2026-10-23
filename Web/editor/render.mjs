import {createDraftEditor} from './draft.mjs';
import {formatBytes,valueText} from '../viewer/model.mjs';

const scalar=field=>!field.present?'Unset':field.value===true?'True':field.value===false?'False':Object.is(field.value,-0)?'-0':String(field.value);
const byteLabel=value=>{const part=formatBytes(value,{limit:64});return part.text+(part.remaining?'… ('+part.remaining+' more bytes)':'');};
const actionLabel=action=>!action.present?'Unset':action.table?'Opaque table ('+action.entries+' entries)':action.values?'['+action.values.map(v=>valueText(v,64)).join(', ')+(action.remaining?', … ('+action.remaining+' more entries)':'')+']':valueText(action.value,64);
const stepLabel=row=>byteLabel(row.type)+(row.type==='none'?' (Stop) · suppress_attack: '+scalar(row.suppressAttack):row.type==='assisted'&&!row.action.present?' (Blizzard\'s suggestion)':' · action: '+actionLabel(row.action));
const messages={'decode-first':'Decode a valid First export before editing.','schema-unavailable':'Editing is unavailable without the local schema.','invalid-structure':'This structure remains read-only.','unsupported-schema':'This envelope schema remains read-only.','strict-index-required':'This structure cannot be edited safely.','invalid-data':'This data remains read-only.'};
export function mountDraftEditor(document,root,{schemaText,readSource,writeClipboard,isVisible=()=>true,onAction=()=>{},focusLease=()=>0}={}){
  const editor=createDraftEditor({schemaText,readSource});let active=true,operation=0,invalid=false,stepPage=0,selectedStepId=null,stepTicket=0,stepListeners=[],stepControls=null;
  const make=(tag,text,id)=>{const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(id)e.setAttribute('id',id);return e;};
  const title=make('h2','Edit a local copy'),intro=make('p','Change body priority and disabled state, or disabled state on an existing action step. Branches remain read-only. Imported metadata is retained as declared data; native availability remains unverified.');
  const edit=make('button','Edit a copy','edit-copy'),discard=make('button','Discard draft','draft-discard');
  const fields=make('div',undefined,'draft-fields');fields.setAttribute('class','draft-fields');
  const priorityLabel=make('label','Priority presence'),presence=make('select',undefined,'draft-priority-presence');priorityLabel.setAttribute('for','draft-priority-presence');
  const priorityValueLabel=make('label','Priority (integer from -100000 to 100000)'),priority=make('input',undefined,'draft-priority');priorityValueLabel.setAttribute('for','draft-priority');priority.setAttribute('type','text');priority.setAttribute('inputmode','numeric');priority.setAttribute('maxlength','8');priority.setAttribute('aria-describedby','draft-status');
  const disabledLabel=make('label','Disabled field'),disabled=make('select',undefined,'draft-disabled');disabledLabel.setAttribute('for','draft-disabled');
  for(const [v,label]of [['absent','Unset'],['set','Explicit integer']]){const o=make('option',label);o.value=v;presence.append(o);}
  for(const [v,label]of [['absent','Unset'],['false','False'],['true','True']]){const o=make('option',label);o.value=v;disabled.append(o);}
  const priorityGroup=make('div'),disabledGroup=make('div');priorityGroup.append(priorityLabel,presence,priorityValueLabel,priority);disabledGroup.append(disabledLabel,disabled);fields.append(priorityGroup,disabledGroup);
  const actions=make('div');actions.setAttribute('class','actions');const review=make('button','Review changes','draft-review'),generate=make('button','Generate new export','draft-generate'),copy=make('button','Copy new export','draft-copy');actions.append(edit,review,generate,copy,discard);
  const status=make('p','Decode First to edit a local copy.','draft-status');status.setAttribute('role','status');status.setAttribute('aria-live','polite');
  const changes=make('div',undefined,'draft-changes'),outputLabel=make('label','Generated export — select and copy manually'),output=make('textarea',undefined,'draft-output');outputLabel.setAttribute('for','draft-output');output.setAttribute('readonly','');output.setAttribute('rows','4');
  const steps=make('div',undefined,'draft-steps');steps.setAttribute('class','draft-fields');
  root.setAttribute('class','draft-editor');root.append(title,intro,fields,steps,actions,status,changes,outputLabel,output);
  for(const b of [edit,discard,review,generate,copy])b.setAttribute('type','button');
  const listeners=[],on=(e,event,fn)=>{const handler=event=>{if(active&&isVisible())return fn(event);};e.addEventListener(event,handler);listeners.push([e,event,handler]);};
  const resetCopy=()=>{operation++;};
  function clearStepListeners(){stepTicket++;for(const [e,event,fn]of stepListeners)e.removeEventListener(event,fn);stepListeners=[];}
  function drawSteps(view){
    clearStepListeners();stepControls=null;steps.replaceChildren();steps.hidden=view.state==='empty';if(steps.hidden)return;
    const ticket=stepTicket,revision=view.revision,current=view.state==='current',page=editor.listSteps(stepPage);stepPage=page.page;
    const sameLease=()=>active&&ticket===stepTicket&&editor.view().revision===revision&&editor.view().state==='current';
    const owns=()=>sameLease()&&isVisible()&&sameLease();
    const stepReady=()=>owns()&&ready()&&owns();
    const localOn=(e,event,fn)=>{const handler=()=>{if(owns())return fn();};e.addEventListener(event,handler);stepListeners.push([e,event,handler]);};
    const label=make('label','Existing step'),select=make('select',undefined,'draft-step-select');label.setAttribute('for','draft-step-select');
    const placeholder=make('option','Choose a step on this page');placeholder.value='';select.append(placeholder);
    for(const row of page.rows){const option=make('option',row.ordinal+'. '+row.section+' · '+row.id+' · '+byteLabel(row.type)+(row.editable?'':' (read-only)'));option.value=row.id;select.append(option);}
    if(!page.rows.some(row=>row.id===selectedStepId))selectedStepId=null;select.value=selectedStepId??'';select.disabled=!current||!page.total;
    const previous=make('button','Previous steps','draft-step-prev'),next=make('button','Next steps','draft-step-next');for(const e of [previous,next])e.setAttribute('type','button');previous.disabled=!current||!page.page;next.disabled=!current||page.page+1>=page.pages;
    const count=make('p',page.total?'Steps '+(page.page*50+1)+'–'+Math.min((page.page+1)*50,page.total)+' of '+page.total:'No existing steps.');
    const row=selectedStepId?editor.step(selectedStepId):null,context=make('p',row?'Step '+row.id+' · '+row.section+' · position '+row.ordinal+(row.parentId?' · parent '+row.parentId+' · '+row.arm+' arm':'')+' · '+stepLabel(row)+(row.unreachable?' · unreachable arm':'')+(row.editable?'':' · read-only'):'Choose a step to inspect its disabled field.','draft-step-context');
    const stateLabel=make('label','Step disabled field'),state=make('select',undefined,'draft-step-disabled');stateLabel.setAttribute('for','draft-step-disabled');
    for(const [v,text]of [['absent','Unset'],['false','False'],['true','True']]){const option=make('option',text);option.value=v;state.append(option);}state.value=row?.disabled.present?String(row.disabled.value):'absent';state.disabled=!current||!row?.editable;state.setAttribute('aria-describedby','draft-step-context');
    steps.append(label,select,count,previous,next,context,stateLabel,state);
    stepControls={select,state};
    localOn(select,'change',()=>{begin();if(!stepReady())return;selectedStepId=page.rows.some(r=>r.id===select.value)?select.value:null;draw(false);if(active&&editor.view().revision===revision&&stepControls)(stepControls.state.disabled?stepControls.select:stepControls.state).focus();});
    const move=delta=>{begin();if(!stepReady())return;stepPage+=delta;selectedStepId=null;draw(false);if(active&&editor.view().revision===revision&&stepControls)stepControls.select.focus();};
    localOn(previous,'click',()=>{if(!previous.disabled)move(-1);});localOn(next,'click',()=>{if(!next.disabled)move(1);});
    const id=row?.id;localOn(state,'change',()=>{if(state.disabled||!id)return;begin();if(!stepReady())return;const focused=document.activeElement===state;if(!editor.setStepDisabled(id,state.value,owns))return;draw(false);if(focused&&active&&editor.view().revision===revision+1&&stepControls)stepControls.state.focus();});
  }
  function draw(updateFields=true,message){
    if(!active)return;const view=editor.view(),empty=view.state==='empty',current=view.state==='current';
    fields.hidden=empty;discard.hidden=empty;discard.disabled=empty;edit.disabled=!empty||typeof schemaText!=='string'||!readSource();
    for(const e of [presence,disabled])e.disabled=!current;
    if(updateFields&&!empty){presence.value=view.fields.priority.present?'set':'absent';priority.value=view.fields.priority.present?scalar(view.fields.priority):'0';disabled.value=view.fields.disabled.present?String(view.fields.disabled.value):'absent';}
    priority.disabled=!current||presence.value==='absent';priority.setAttribute('aria-invalid',String(invalid));
    review.disabled=!current||invalid;generate.disabled=!current||invalid||!view.review;copy.disabled=!current||invalid||view.output===null;
    output.value=view.output??'';output.hidden=outputLabel.hidden=view.output===null;
    drawSteps(view);
    changes.replaceChildren();
    if(view.review){changes.append(make('h3','Reviewed changes'));if(!view.review.changes.length)changes.append(make('p','No structural differences.'));
      for(const c of view.review.changes)changes.append(make('p',(c.stepId?'Step '+c.stepId+' ('+c.section+', position '+c.ordinal+') · Disabled':c.field==='priority'?'Priority':'Disabled')+': '+scalar(c.before)+' → '+scalar(c.after)));}
    status.textContent=message??(view.state==='retired'?'First changed. This draft is retired; recover the visible values or discard it.':invalid?'Enter an integer from -100000 to 100000, or choose Unset.':view.reason?(messages[view.reason]??'Export unavailable: '+view.reason+'.'):empty?'Decode First to edit a local copy.':view.output!==null?'New export generated. The original export is unchanged.':view.review?'Review complete. Generate an export explicitly.':'Local draft. Review changes before generating an export.');
  }
  function ready(){if(!editor.sync()){resetCopy();draw();return false;}return true;}
  function begin(){resetCopy();onAction();}
  on(edit,'click',()=>{begin();invalid=false;stepPage=0;selectedStepId=null;editor.start();draw();if(editor.view().state==='current')presence.focus();});
  on(discard,'click',()=>{begin();editor.discard();invalid=false;stepPage=0;selectedStepId=null;draw();edit.focus();});
  const applyPriority=()=>{
    begin();if(!ready())return;editor.invalidateReview();
    const value=priority.value;invalid=presence.value!=='absent'&&(!/^-?(0|[1-9][0-9]{0,5})$/.test(value)||!editor.setPriority(true,Number(value)));
    if(presence.value==='absent')editor.setPriority(false);
    draw(false,invalid?'Enter an integer from -100000 to 100000, or choose Unset.':undefined);
  };
  on(presence,'change',applyPriority);on(priority,'input',applyPriority);
  on(disabled,'change',()=>{begin();if(!ready())return;editor.setDisabled(disabled.value);draw(false);});
  on(review,'click',()=>{begin();if(!ready()||invalid)return;editor.review();draw(false);});
  on(generate,'click',()=>{begin();if(!ready()||invalid)return;editor.generate();draw(false);});
  on(copy,'click',async()=>{
    begin();if(!ready()||invalid)return;const view=editor.view();if(view.output===null)return;
    const token=operation,revision=view.revision,text=view.output,focus=focusLease(),element=document.activeElement;
    const current=()=>active&&token===operation&&isVisible()&&focus===focusLease()&&editor.sync()&&editor.view().revision===revision&&editor.view().output===text;
    try{if(typeof writeClipboard!=='function')throw Error('clipboard-unavailable');await writeClipboard(text);if(current())status.textContent='New export copied.';else if(active&&isVisible()&&editor.view().state==='retired')draw();}
    catch{if(!current()){if(active&&editor.view().state==='retired')draw();return;}status.textContent='Clipboard unavailable. Select and copy the generated export below.';if(document.activeElement===element){output.focus();output.select();}}
  });
  draw();
  return {
    refresh(){if(!active)return;editor.sync();draw();},
    retire(){if(!active)return;resetCopy();editor.retire();draw();},
    supersedeClipboard(){resetCopy();},
    dispose(){if(!active)return;active=false;resetCopy();clearStepListeners();editor.dispose();for(const [e,event,fn]of listeners)e.removeEventListener(event,fn);root.replaceChildren();}
  };
}
