export class DCLogic {
 constructor(props){this.props=props||{};this.state={};}
 setState(update,callback){if(this.moduleStores){this.moduleStores.dispatchCompatibility(update);callback?.();return;}const patch=typeof update==='function'?update(this.state):update;this.state={...this.state,...patch};if(this.host)this.host.forceUpdate(callback);else callback?.();}
 forceUpdate(){this.host?.forceUpdate();}
 componentDidMount(){} componentDidUpdate(){} componentWillUnmount(){}
}
