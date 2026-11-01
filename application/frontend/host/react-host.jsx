import {attachMeetingMinutes} from '../modules/meetings/minutes.js';
import {attachMeetingAudio} from '../modules/meetings/service.js';
import {attachSpecialists} from '../modules/ai/specialists.js';
import {attachBusiness} from '../modules/business/service.js';
import {attachAIActions} from '../modules/ai/actions.js';
import {attachAssistant} from '../modules/ai/assistant.js';
import {attachAIGateway} from '../modules/ai/gateway.js';
import {attachMessaging} from '../modules/messaging/service.js';
import {attachDocuments} from '../modules/documents/service.js';
import {attachCases} from '../modules/cases/supabase.js';
import {attachAdherents} from '../modules/contacts/adherents-supabase.js';
import {attachConvocationHistory} from '../modules/messaging/convocation-history.js';
import {attachPublicationNotices} from '../modules/agenda/notifications.js';
import {attachAgendaWorkflows} from '../modules/agenda/workflows.js';
import {initialAgenda} from '../modules/agenda/presenter.js';
import {attachAgenda} from '../modules/agenda/service.js';
import {attachS01Identity} from '../services/identity-s01.js';
import {attachS01Auth} from '../services/auth-s01.js';
import React from 'react';import {createRoot} from 'react-dom/client';import {Component} from '../generated/controller.js';import Shell from '../generated/shell.jsx';
import {createModuleStores} from '../state/module-stores.js';import {attachModuleServices} from '../services/module-services.js';
window.React=React;
const defaults={userName:'Sophie Marchand',orgName:'Section syndicale Métallurgie — Valenciennes',showAiDisclaimer:true};
class Host extends React.Component {
 constructor(props){super(props);this.controller=new Component(defaults);this.controller.host=this;const stores=createModuleStores({...this.controller.state,...initialAgenda()},()=>this.forceUpdate());Object.defineProperty(this.controller,'state',{get:()=>stores.snapshot(),configurable:false});this.controller.moduleStores=stores;attachModuleServices(this.controller,stores);if(window.uniionS01){const auth=attachS01Auth(this.controller,window.uniionS01.fetch);attachS01Identity(this.controller,auth.request,window.uniionS01.organizationId);attachAgenda(this.controller,auth.request,window.uniionS01.organizationId);attachDocuments(this.controller,auth.request,window.uniionS01.organizationId);attachAgendaWorkflows(this.controller,auth.request,window.uniionS01.organizationId);attachPublicationNotices(this.controller,auth.request,window.uniionS01.organizationId);attachConvocationHistory(this.controller,auth.request,window.uniionS01.organizationId);attachAdherents(this.controller,auth.request,window.uniionS01.organizationId);attachCases(this.controller,auth.request,window.uniionS01.organizationId);attachMessaging(this.controller,auth.request,window.uniionS01.organizationId);attachBusiness(this.controller,auth.request,window.uniionS01.organizationId);attachAIGateway(this.controller,auth.request,window.uniionS01.organizationId);attachAssistant(this.controller,auth.request,window.uniionS01.organizationId);attachAIActions(this.controller,auth.request,window.uniionS01.organizationId);attachSpecialists(this.controller,auth.request,window.uniionS01.organizationId);attachMeetingAudio(this.controller,auth.request,window.uniionS01.organizationId);attachMeetingMinutes(this.controller,auth.request,window.uniionS01.organizationId);this.resumeSession=auth.resume;}}
 componentDidMount(){this.controller.componentDidMount();this.resumeSession?.();}
 componentDidUpdate(prev){this.controller.componentDidUpdate(prev);}
 componentWillUnmount(){this.controller.componentWillUnmount();}
 render(){return <div className="sc-host" data-sc-name="Root"><Shell values={{...defaults,...this.controller.renderVals()}}/></div>;}
}
createRoot(document.getElementById('dc-root')).render(<Host/>);
