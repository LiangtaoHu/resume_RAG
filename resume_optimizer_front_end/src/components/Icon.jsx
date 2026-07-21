import "../css/Icon.css"

// Rechange into generic name
function Icon({obj, isSelected, ...restProps}) {
    return (
        <div className={`resume-icon ${isSelected? 'selected-icon' : ""}`} {...restProps}>
            <p>{obj.SK}</p>
        </div>
    )
}

export default Icon